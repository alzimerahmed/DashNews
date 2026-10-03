//
//  LocalStatusSyncStore.swift
//  Account
//
//  Created by DashNews on 2/14/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import os
import RSDatabase
import RSDatabaseObjC

/// Local mirror of the article statuses that are synced to iCloud for a local
/// (OnDisk) account. One row per article, holding the last-known synced status
/// and the timestamp of the last change, plus a dirty flag for rows that still
/// need to be pushed upstream.
///
/// This store is what makes conflict resolution possible: when a remote change
/// arrives we compare its `lastModified` against the row's `lastModified`, and
/// when we push we only push dirty rows. It is a small SQLite database in the
/// account's data folder, following the same pattern as `SyncDatabase`.
final class LocalStatusSyncStore: Sendable {

	let databasePath: String

	nonisolated(unsafe) private let database: FMDatabase // Used on serial dispatch queue only
	private let serialDispatchQueue: DispatchQueue
	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "LocalStatusSyncStore")

	init(databasePath: String) {
		self.databasePath = databasePath
		self.serialDispatchQueue = DispatchQueue(label: "LocalStatusSyncStore")
		self.database = FMDatabase.openAndSetUpDatabase(path: databasePath)
		serialDispatchQueue.sync { [database] in
			database.runCreateStatements(Self.tableCreationStatements)
		}
	}

	// MARK: - API

	/// Records a local status change: upserts the row with the new status and
	/// timestamp and marks it dirty so the next send pushes it upstream.
	func recordLocalChange(articleID: String, read: Bool, starred: Bool, lastModified: Date) {
		let recordName = LocalStatusRecord.recordName(for: articleID)
		serialDispatchQueue.sync { [database] in
			_ = database.executeUpdate("""
				INSERT INTO localStatus (articleID, recordName, read, starred, lastModified, dirty) VALUES (?, ?, ?, ?, ?, 1)
				ON CONFLICT(articleID) DO UPDATE SET recordName = excluded.recordName, read = excluded.read, starred = excluded.starred, lastModified = excluded.lastModified, dirty = 1
				""", withArgumentsIn: [articleID, recordName, read, starred, lastModified.timeIntervalSince1970])
		}
	}

	/// Batch variant of `recordLocalChange` — one queue hop, one transaction.
	/// A change is only written when it is at least as new as the stored row,
	/// so async queueing can't let an earlier-queued write clobber a later one.
	func recordLocalChanges(_ changes: [(articleID: String, read: Bool, starred: Bool)], lastModified: Date) {
		guard !changes.isEmpty else {
			return
		}
		let timestamp = lastModified.timeIntervalSince1970
		serialDispatchQueue.sync { [database] in
			database.beginTransaction()
			for change in changes {
				let recordName = LocalStatusRecord.recordName(for: change.articleID)
				_ = database.executeUpdate("""
					INSERT INTO localStatus (articleID, recordName, read, starred, lastModified, dirty) VALUES (?, ?, ?, ?, ?, 1)
					ON CONFLICT(articleID) DO UPDATE SET recordName = excluded.recordName, read = excluded.read, starred = excluded.starred, lastModified = excluded.lastModified, dirty = 1
					WHERE excluded.lastModified >= localStatus.lastModified
					""", withArgumentsIn: [change.articleID, recordName, change.read, change.starred, timestamp])
			}
			database.commit()
		}
	}

	/// Returns the locally known status for articleID, or nil if none.
	func status(for articleID: String) -> LocalStatusRecord? {
		serialDispatchQueue.sync { [database] in
			Self.status(for: articleID, database: database)
		}
	}

	/// Batch variant of `status(for:)` — one SELECT with an IN clause per
	/// 500-ID chunk (SQLite host-variable limits) instead of N queries.
	func statuses(for articleIDs: Set<String>) -> [String: LocalStatusRecord] {
		guard !articleIDs.isEmpty else {
			return [:]
		}
		return serialDispatchQueue.sync { [database] in
			var result = [String: LocalStatusRecord]()
			let ids = Array(articleIDs)
			for start in stride(from: 0, to: ids.count, by: 500) {
				let chunk = Array(ids[start..<min(start + 500, ids.count)])
				let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
				guard let resultSet = database.executeQuery("SELECT articleID, read, starred, lastModified FROM localStatus WHERE articleID IN (\(placeholders))", withArgumentsIn: chunk) else {
					Self.logDatabaseError("select statuses", database)
					continue
				}
				defer {
					resultSet.close()
				}
				while resultSet.next() {
					guard let articleID = resultSet.object(forColumnIndex: 0) as? String else {
						continue
					}
					result[articleID] = LocalStatusRecord(articleID: articleID, read: resultSet.bool(forColumnIndex: 1), starred: resultSet.bool(forColumnIndex: 2), lastModified: Date(timeIntervalSince1970: resultSet.double(forColumnIndex: 3)))
				}
			}
			return result
		}
	}

	/// Returns all dirty (not yet pushed) rows.
	func selectDirty() -> [LocalStatusRecord] {
		serialDispatchQueue.sync { [database] in
			Self.selectDirty(database: database)
		}
	}

	/// Marks rows as clean after they were successfully pushed upstream.
	/// A row that changed again while the push was in flight keeps its dirty
	/// flag, because its timestamp moved past `lastModified`.
	func markClean(articleIDs: Set<String>, pushedBefore lastModified: Date) {
		guard !articleIDs.isEmpty else {
			return
		}
		let timestamp = lastModified.timeIntervalSince1970
		serialDispatchQueue.sync { [database] in
			database.beginTransaction()
			let ids = Array(articleIDs)
			for start in stride(from: 0, to: ids.count, by: 500) {
				let chunk = Array(ids[start..<min(start + 500, ids.count)])
				let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
				var arguments: [Any] = [timestamp]
				arguments.append(contentsOf: chunk)
				_ = database.executeUpdate("UPDATE localStatus SET dirty = 0 WHERE lastModified <= ? AND articleID IN (\(placeholders))", withArgumentsIn: arguments)
			}
			database.commit()
		}
	}

	/// Applies a remote status if it is newer than the locally known one.
	/// Returns true when the remote change was applied (the caller must then
	/// update the account's article statuses), false when the local version
	/// already wins.
	func applyRemote(_ remote: LocalStatusRecord) -> Bool {
		let recordName = LocalStatusRecord.recordName(for: remote.articleID)
		return serialDispatchQueue.sync { [database] in
			let local = Self.status(for: remote.articleID, database: database)
			guard let local else {
				_ = database.executeUpdate("""
					INSERT INTO localStatus (articleID, recordName, read, starred, lastModified, dirty) VALUES (?, ?, ?, ?, ?, 0)
					""", withArgumentsIn: [remote.articleID, recordName, remote.read, remote.starred, remote.lastModified.timeIntervalSince1970])
				return true
			}
			guard local.remoteShouldBeApplied(remote: remote) else {
				return false
			}
			// The winning row is not dirty: it came from upstream, so it must not
			// be pushed back. A row that was dirty with an older timestamp loses
			// here too — the remote change is newer, so the queued local change
			// is stale and gets dropped.
			_ = database.executeUpdate("""
				INSERT INTO localStatus (articleID, recordName, read, starred, lastModified, dirty) VALUES (?, ?, ?, ?, ?, 0)
				ON CONFLICT(articleID) DO UPDATE SET recordName = excluded.recordName, read = excluded.read, starred = excluded.starred, lastModified = excluded.lastModified, dirty = 0
				""", withArgumentsIn: [remote.articleID, recordName, remote.read, remote.starred, remote.lastModified.timeIntervalSince1970])
			return true
		}
	}

	/// Reverse lookup for deleted CloudKit records: deleted records carry no
	/// fields, only their (hashed) record name.
	func articleID(forRecordName recordName: String) -> String? {
		serialDispatchQueue.sync { [database] in
			guard let resultSet = database.executeQuery("SELECT articleID FROM localStatus WHERE recordName = ?", withArgumentsIn: [recordName]) else {
				Self.logDatabaseError("select articleID for recordName", database)
				return nil
			}
			defer {
				resultSet.close()
			}
			guard resultSet.next(), let articleID = resultSet.object(forColumnIndex: 0) as? String else {
				return nil
			}
			return articleID
		}
	}

	/// Removes the mirror row for an articleID (used when a remote record was
	/// deleted and the row is clean).
	func deleteRow(articleID: String) {
		serialDispatchQueue.sync { [database] in
			_ = database.executeUpdate("DELETE FROM localStatus WHERE articleID = ? AND dirty = 0", withArgumentsIn: [articleID])
		}
	}

	/// Removes all rows. Used when the sync feature is turned off.
	func deleteAll() {
		serialDispatchQueue.sync { [database] in
			_ = database.executeUpdate("DELETE FROM localStatus", withArgumentsIn: [])
		}
	}

	// MARK: - Private

	private static func status(for articleID: String, database: FMDatabase) -> LocalStatusRecord? {
		guard let resultSet = database.executeQuery("SELECT read, starred, lastModified FROM localStatus WHERE articleID = ?", withArgumentsIn: [articleID]) else {
			logDatabaseError("select status", database)
			return nil
		}
		defer {
			resultSet.close()
		}
		guard resultSet.next() else {
			return nil
		}
		return LocalStatusRecord(articleID: articleID, read: resultSet.bool(forColumnIndex: 0), starred: resultSet.bool(forColumnIndex: 1), lastModified: Date(timeIntervalSince1970: resultSet.double(forColumnIndex: 2)))
	}

	private static func selectDirty(database: FMDatabase) -> [LocalStatusRecord] {
		guard let resultSet = database.executeQuery("SELECT articleID, read, starred, lastModified FROM localStatus WHERE dirty = 1 ORDER BY lastModified", withArgumentsIn: []) else {
			logDatabaseError("select dirty", database)
			return []
		}
		defer {
			resultSet.close()
		}

		var records = [LocalStatusRecord]()
		while resultSet.next() {
			guard let articleID = resultSet.object(forColumnIndex: 0) as? String else {
				continue
			}
			records.append(LocalStatusRecord(articleID: articleID, read: resultSet.bool(forColumnIndex: 1), starred: resultSet.bool(forColumnIndex: 2), lastModified: Date(timeIntervalSince1970: resultSet.double(forColumnIndex: 3))))
		}
		return records
	}

	private static func logDatabaseError(_ operation: String, _ database: FMDatabase) {
		logger.error("\(operation, privacy: .public) failed — \(database.lastErrorMessage(), privacy: .public)")
	}

}

private extension LocalStatusSyncStore {

	static let tableCreationStatements = """
	CREATE TABLE if not EXISTS localStatus (articleID TEXT NOT NULL PRIMARY KEY, recordName TEXT NOT NULL, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, lastModified REAL NOT NULL DEFAULT 0, dirty BOOL NOT NULL DEFAULT 0);
	CREATE INDEX if not EXISTS localStatusRecordName ON localStatus (recordName);
	"""

}
