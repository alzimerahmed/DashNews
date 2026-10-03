//
//  LocalStatusRecord.swift
//  Account
//
//  Created by DashNews on 2/14/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import CloudKit
import CryptoKit

/// One article's read/starred status as synced through iCloud for local (OnDisk)
/// accounts. This is the pure mapping/conflict layer of the local-account status
/// sync: it knows how to encode itself into and decode itself from a CKRecord,
/// and how to resolve conflicts between a local and a remote version.
///
/// Conflicts are resolved latest-wins by `lastModified`, the timestamp written by
/// whichever device made the change. Record names are deterministic (a hash of
/// the articleID) so that both devices write to the same record and the newer
/// timestamp wins.
struct LocalStatusRecord: Equatable, Sendable {

	static let recordType = "LocalArticleStatus"

	enum Fields {
		static let articleID = "articleID"
		static let read = "read"
		static let starred = "starred"
		static let lastModified = "lastModified"
	}

	let articleID: String
	let read: Bool
	let starred: Bool
	let lastModified: Date

	init(articleID: String, read: Bool, starred: Bool, lastModified: Date) {
		self.articleID = articleID
		self.read = read
		self.starred = starred
		self.lastModified = lastModified
	}

	// MARK: - CKRecord mapping

	/// Deterministic record name for an articleID. CloudKit record names are
	/// limited to 255 bytes, while articleIDs can be longer, so the articleID is
	/// hashed. The articleID itself is stored in a field on the record.
	static func recordName(for articleID: String) -> String {
		let digest = SHA256.hash(data: Data(articleID.utf8))
		return digest.map { String(format: "%02x", $0) }.joined()
	}

	static func recordID(for articleID: String, zoneID: CKRecordZone.ID) -> CKRecord.ID {
		CKRecord.ID(recordName: recordName(for: articleID), zoneID: zoneID)
	}

	func makeCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
		let record = CKRecord(recordType: Self.recordType, recordID: Self.recordID(for: articleID, zoneID: zoneID))
		record[Fields.articleID] = articleID
		record[Fields.read] = read ? "1" : "0"
		record[Fields.starred] = starred ? "1" : "0"
		record[Fields.lastModified] = lastModified
		return record
	}

	/// Decodes a status record. Returns nil for anything that is not a usable
	/// LocalArticleStatus record (wrong type, missing articleID, unreadable
	/// fields) so callers can skip it instead of crashing.
	init?(record: CKRecord) {
		guard record.recordType == Self.recordType else {
			return nil
		}
		guard let articleID = record[Fields.articleID] as? String else {
			return nil
		}
		let readValue = record[Fields.read] as? String ?? "0"
		let starredValue = record[Fields.starred] as? String ?? "0"
		let lastModified = record[Fields.lastModified] as? Date ?? record.modificationDate ?? record.creationDate ?? Date(timeIntervalSince1970: 0)
		self.init(articleID: articleID, read: readValue == "1", starred: starredValue == "1", lastModified: lastModified)
	}

	// MARK: - Conflict resolution

	/// Latest-wins by date. If the timestamps are equal, the remote version wins:
	/// this makes the result deterministic across devices and means a device
	/// that just fetched a remote change never re-uploads a stale local copy.
	static func resolve(local: LocalStatusRecord, remote: LocalStatusRecord) -> LocalStatusRecord {
		guard local.lastModified > remote.lastModified else {
			return remote
		}
		return local
	}

	/// Returns the remote record if it should be applied to local storage,
	/// i.e. if it is at least as new as the locally known version.
	func remoteShouldBeApplied(remote: LocalStatusRecord) -> Bool {
		Self.resolve(local: self, remote: remote) != self
	}

}
