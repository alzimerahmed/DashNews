//
//  LocalStatusSyncStoreTests.swift
//  AccountTests
//
//  Created by DashNews on 2/14/26.
//  Copyright © 2026 Alzimer Ahmed, LLC. All rights reserved.
//

import Testing
import Foundation
@testable import Account

@MainActor struct LocalStatusSyncStoreTests {

	private func makeStore() -> LocalStatusSyncStore {
		let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
			.appendingPathComponent("LocalStatusSyncStoreTests-\(UUID().uuidString)", isDirectory: true)
		try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		let path = directory.appendingPathComponent("LocalStatus.sqlite3").path
		return LocalStatusSyncStore(databasePath: path)
	}

	@Test func recordLocalChangeAndReadBack() {
		let store = makeStore()
		let date = Date(timeIntervalSince1970: 500)
		store.recordLocalChange(articleID: "a", read: true, starred: false, lastModified: date)

		let status = store.status(for: "a")
		#expect(status == LocalStatusRecord(articleID: "a", read: true, starred: false, lastModified: date))
		#expect(store.selectDirty().count == 1)
	}

	@Test func recordLocalChangeMergesWithExistingStatus() {
		let store = makeStore()
		store.recordLocalChange(articleID: "a", read: true, starred: false, lastModified: Date(timeIntervalSince1970: 100))
		store.recordLocalChange(articleID: "a", read: true, starred: true, lastModified: Date(timeIntervalSince1970: 200))

		let status = store.status(for: "a")
		#expect(status?.read == true)
		#expect(status?.starred == true)
		#expect(status?.lastModified == Date(timeIntervalSince1970: 200))
	}

	@Test func markCleanOnlyTouchesRowsPushedBefore() {
		let store = makeStore()
		store.recordLocalChange(articleID: "a", read: true, starred: false, lastModified: Date(timeIntervalSince1970: 100))
		store.recordLocalChange(articleID: "b", read: false, starred: true, lastModified: Date(timeIntervalSince1970: 300))

		store.markClean(articleIDs: ["a", "b"], pushedBefore: Date(timeIntervalSince1970: 200))

		let dirtyIDs = Set(store.selectDirty().map { $0.articleID })
		#expect(dirtyIDs == ["b"])
	}

	@Test func applyRemoteInsertsWhenNoLocalRow() {
		let store = makeStore()
		let remote = LocalStatusRecord(articleID: "a", read: true, starred: true, lastModified: Date(timeIntervalSince1970: 100))

		#expect(store.applyRemote(remote))
		#expect(store.status(for: "a") == remote)
		#expect(store.selectDirty().isEmpty)
	}

	@Test func applyRemoteNewerWinsAndDropsStaleLocalChange() {
		let store = makeStore()
		store.recordLocalChange(articleID: "a", read: false, starred: false, lastModified: Date(timeIntervalSince1970: 100))
		let newerRemote = LocalStatusRecord(articleID: "a", read: true, starred: true, lastModified: Date(timeIntervalSince1970: 200))

		#expect(store.applyRemote(newerRemote))
		#expect(store.status(for: "a") == newerRemote)
		// The stale queued local change was dropped, not left dirty.
		#expect(store.selectDirty().isEmpty)
	}

	@Test func applyRemoteOlderLosesToLocalChange() {
		let store = makeStore()
		store.recordLocalChange(articleID: "a", read: true, starred: false, lastModified: Date(timeIntervalSince1970: 300))
		let olderRemote = LocalStatusRecord(articleID: "a", read: false, starred: false, lastModified: Date(timeIntervalSince1970: 100))

		#expect(!store.applyRemote(olderRemote))
		#expect(store.status(for: "a")?.read == true)
		// The local change stays queued for sending.
		#expect(store.selectDirty().count == 1)
	}

	@Test func applyRemoteTiePrefersRemote() {
		let store = makeStore()
		store.recordLocalChange(articleID: "a", read: false, starred: false, lastModified: Date(timeIntervalSince1970: 100))
		let tieRemote = LocalStatusRecord(articleID: "a", read: true, starred: false, lastModified: Date(timeIntervalSince1970: 100))

		#expect(store.applyRemote(tieRemote))
		#expect(store.status(for: "a")?.read == true)
	}

	@Test func deleteAllClearsStore() {
		let store = makeStore()
		store.recordLocalChange(articleID: "a", read: true, starred: false, lastModified: Date())
		store.deleteAll()

		#expect(store.status(for: "a") == nil)
		#expect(store.selectDirty().isEmpty)
	}

	@Test func recordNameReverseLookup() {
		let store = makeStore()
		store.recordLocalChange(articleID: "a", read: true, starred: false, lastModified: Date())

		let recordName = LocalStatusRecord.recordName(for: "a")
		#expect(store.articleID(forRecordName: recordName) == "a")
		#expect(store.articleID(forRecordName: "unknown") == nil)
	}

	@Test func deleteRowOnlyRemovesCleanRows() {
		let store = makeStore()
		store.recordLocalChange(articleID: "a", read: true, starred: false, lastModified: Date())

		store.deleteRow(articleID: "a")
		#expect(store.status(for: "a") != nil)

		store.markClean(articleIDs: ["a"], pushedBefore: Date(timeIntervalSince1970: 10_000))
		store.deleteRow(articleID: "a")
		#expect(store.status(for: "a") == nil)
	}

}
