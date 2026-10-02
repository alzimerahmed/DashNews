//
//  LocalCloudStatusSyncer.swift
//  Account
//
//  Created by DashNews on 2/14/26.
//  Copyright © 2026 Alzimer Ahmed, LLC. All rights reserved.
//

import Foundation
import CloudKit
import os
import RSCore
import Articles
import CloudKitSync

/// Lightweight iCloud (CloudKit) sync of read/starred article status for local
/// (OnDisk) accounts. Local accounts have no server to reconcile with, so this
/// engine mirrors each status change into the account's private CloudKit
/// database and applies remote changes back, latest-wins by change date.
///
/// Graceful degradation: when iCloud is unavailable (not signed in, restricted,
/// or paused pending T&C acceptance) every stage is skipped and one log entry
/// is posted; the local account keeps working unchanged. The engine retries
/// when the system posts `CKAccountChanged`.
///
/// Only the account's own status changes are queued: while remote changes are
/// being applied, queueing is suppressed so a fetched change isn't echoed back.
@MainActor final class LocalCloudStatusSyncer {

	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "LocalCloudStatusSyncer")
	private static let sendBatchSize = 200

	private weak var account: Account?
	private let store: LocalStatusSyncStore
	private let zone: LocalStatusZone

	/// Set while remote changes are being applied to the account, so the
	/// account's status-change hook doesn't re-queue them for sending.
	private var isApplyingRemoteChanges = false

	/// Set when the CloudKit container reports the iCloud account isn't
	/// available; cleared when the system posts CKAccountChanged.
	private var iCloudAccountIsUnavailable = false

	/// True once the zone subscription has been established this session.
	private var isSubscribed = false

	init?(account: Account) {
		guard let container = Self.makeContainer() else {
			Self.logger.info("LocalCloudStatusSyncer: no CloudKit container identifier — sync disabled")
			return nil
		}
		self.account = account
		let storePath = (account.dataFolder as NSString).appendingPathComponent("LocalStatus.sqlite3")
		self.store = LocalStatusSyncStore(databasePath: storePath)
		self.zone = LocalStatusZone(container: container)

		NotificationCenter.default.addObserver(self, selector: #selector(handleCKAccountChanged(_:)), name: .CKAccountChanged, object: nil)
	}

	// CKAccountChanged can arrive on any thread.
	@objc nonisolated func handleCKAccountChanged(_ note: Notification) {
		Task { @MainActor in
			iCloudAccountIsUnavailable = false
			Self.logger.info("LocalCloudStatusSyncer: iCloud account changed — retrying sync")
			try? await syncArticleStatus()
		}
	}

	// MARK: - Queueing local changes

	/// Records a local status change in the mirror store so the next send
	/// pushes it upstream. Called from the account's status-change hook.
	func queueLocalChange(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) {
		guard !articleIDs.isEmpty else {
			return
		}
		guard !isApplyingRemoteChanges else {
			return
		}

		let now = Date()
		for articleID in articleIDs {
			let existing = store.status(for: articleID)
			let read = statusKey == .read ? flag : (existing?.read ?? false)
			let starred = statusKey == .starred ? flag : (existing?.starred ?? false)
			store.recordLocalChange(articleID: articleID, read: read, starred: starred, lastModified: now)
		}
	}

	// MARK: - Sync rounds

	/// One full round: pull remote changes, then push local ones.
	/// Returns true if any meaningful work was done.
	@discardableResult
	func syncArticleStatus() async throws -> Bool {
		guard !Platform.isRunningUnitTests else {
			return false
		}
		guard await checkiCloudAvailability() else {
			return false
		}

		let pulled = try await pullRemoteChanges()
		let pushed = try await pushLocalChanges()
		return pulled || pushed
	}

	/// Pushes queued local status changes upstream.
	func sendArticleStatus() async throws {
		guard !Platform.isRunningUnitTests else {
			return
		}
		guard await checkiCloudAvailability() else {
			return
		}
		try await pushLocalChanges()
	}

	/// Pulls remote status changes and applies them to the account.
	func refreshArticleStatus() async throws {
		guard !Platform.isRunningUnitTests else {
			return
		}
		guard await checkiCloudAvailability() else {
			return
		}
		try await pullRemoteChanges()
	}

	/// Deletes the mirror store contents and stops observing notifications.
	/// Called when the feature is turned off.
	func clearMirror() {
		store.deleteAll()
	}

	// MARK: - Availability

	private static func makeContainer() -> CKContainer? {
		guard let orgID = Bundle.main.object(forInfoDictionaryKey: "OrganizationIdentifier") as? String else {
			return nil
		}
		return CKContainer(identifier: "iCloud.\(orgID).DashNews")
	}

	private func checkiCloudAvailability() async -> Bool {
		guard let container = zone.container else {
			return false
		}
		do {
			let status = try await container.accountStatus()
			if status == .available {
				return true
			}
			logUnavailableOnce("iCloud account status is \(status.rawValue)")
			return false
		} catch {
			logUnavailableOnce("iCloud account status check failed: \(error.localizedDescription)")
			return false
		}
	}

	private func logUnavailableOnce(_ message: String) {
		guard !iCloudAccountIsUnavailable else {
			return
		}
		iCloudAccountIsUnavailable = true
		Self.logger.info("LocalCloudStatusSyncer: \(message, privacy: .public) — iCloud status sync paused until CKAccountChanged")
	}

	// MARK: - Pull

	private func pullRemoteChanges() async throws -> Bool {
		let delegate = LocalStatusZoneDelegate(account: account, store: store) { [weak self] articleIDs, statusKey, flag in
			await self?.applyRemoteChange(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
		}
		zone.delegate = delegate

		try await subscribeIfNeeded()

		do {
			try await zone.fetchChangesInZone()
		} catch {
			if case CloudKitZoneError.userDeletedZone = error {
				try await zone.createZoneRecord()
				try await zone.fetchChangesInZone()
				return delegate.appliedCount > 0
			}
			throw error
		}
		return delegate.appliedCount > 0
	}

	private func applyRemoteChange(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async {
		guard let account else {
			return
		}
		isApplyingRemoteChanges = true
		defer {
			isApplyingRemoteChanges = false
		}
		await account.updateStatusesAsync(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
	}

	private func subscribeIfNeeded() async throws {
		guard !isSubscribed else {
			return
		}
		// A missing subscription only costs push latency — sync still runs on
		// the periodic status-sync timer — so failures are logged, not thrown.
		do {
			try await zone.subscribeToZoneChanges()
		} catch {
			Self.logger.info("LocalCloudStatusSyncer: zone subscription failed: \(error.localizedDescription, privacy: .public)")
		}
		isSubscribed = true
	}

	// MARK: - Push

	private func pushLocalChanges() async throws -> Bool {
		var pushedAny = false

		while true {
			// Captured before the records are built: any change queued after
			// this point has a later timestamp and stays dirty for the next
			// send, even though the push completes after it was queued.
			let pushStartedAt = Date()
			let dirty = store.selectDirty()
			guard !dirty.isEmpty else {
				break
			}

			let batch = Array(dirty.prefix(Self.sendBatchSize))
			let records = batch.map { $0.makeCKRecord(zoneID: zone.zoneID) }
			try await zone.save(records)

			// Only rows whose timestamp didn't move while the push was in
			// flight are marked clean; changed rows stay dirty and re-send.
			store.markClean(articleIDs: Set(batch.map { $0.articleID }), pushedBefore: pushStartedAt)
			pushedAny = true

			if batch.count < dirty.count {
				continue
			}
			break
		}

		return pushedAny
	}

}

// MARK: - Zone delegate

private final class LocalStatusZoneDelegate: CloudKitZoneDelegate {

	private weak var account: Account?
	private let store: LocalStatusSyncStore
	private let applyChange: @MainActor @Sendable (Set<String>, ArticleStatus.Key, Bool) async -> Void
	private(set) var appliedCount = 0

	init(account: Account?, store: LocalStatusSyncStore, applyChange: @escaping @MainActor @Sendable (Set<String>, ArticleStatus.Key, Bool) async -> Void) {
		self.account = account
		self.store = store
		self.applyChange = applyChange
	}

	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey]) async throws {
		var readIDs = Set<String>()
		var unreadIDs = Set<String>()
		var starredIDs = Set<String>()
		var unstarredIDs = Set<String>()

		for record in changed {
			guard let remote = LocalStatusRecord(record: record) else {
				continue
			}
			guard store.applyRemote(remote) else {
				continue
			}
			appliedCount += 1
			if remote.read {
				readIDs.insert(remote.articleID)
			} else {
				unreadIDs.insert(remote.articleID)
			}
			if remote.starred {
				starredIDs.insert(remote.articleID)
			} else {
				unstarredIDs.insert(remote.articleID)
			}
		}

		// Deleted records carry no fields, only their (hashed) record name. A
		// clean mirror row for a deleted record is dropped; dirty rows keep
		// their queued change so it gets re-pushed (recreating the record).
		for key in deleted {
			guard key.recordType == LocalStatusRecord.recordType else {
				continue
			}
			guard let articleID = store.articleID(forRecordName: key.recordID.recordName) else {
				continue
			}
			store.deleteRow(articleID: articleID)
		}

		if !readIDs.isEmpty {
			await applyChange(readIDs, .read, true)
		}
		if !unreadIDs.isEmpty {
			await applyChange(unreadIDs, .read, false)
		}
		if !starredIDs.isEmpty {
			await applyChange(starredIDs, .starred, true)
		}
		if !unstarredIDs.isEmpty {
			await applyChange(unstarredIDs, .starred, false)
		}
	}

}
