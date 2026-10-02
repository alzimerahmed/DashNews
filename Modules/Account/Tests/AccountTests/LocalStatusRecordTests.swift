//
//  LocalStatusRecordTests.swift
//  AccountTests
//
//  Created by DashNews on 2/14/26.
//  Copyright © 2026 Alzimer Ahmed, LLC. All rights reserved.
//

import Testing
import CloudKit
@testable import Account

@MainActor struct LocalStatusRecordTests {

	let zoneID = CKRecordZone.ID(zoneName: "LocalStatus", ownerName: CKCurrentUserDefaultName)

	@Test func recordNameIsDeterministicAndBounded() {
		let first = LocalStatusRecord.recordName(for: "https://example.com/feed.xml+article-1")
		let second = LocalStatusRecord.recordName(for: "https://example.com/feed.xml+article-1")
		#expect(first == second)
		#expect(first.count == 64)
		// A very long articleID still maps into CloudKit's 255-byte record-name limit.
		let longID = String(repeating: "x", count: 500)
		#expect(LocalStatusRecord.recordName(for: longID).count == 64)
	}

	@Test func makeCKRecordRoundTrip() throws {
		let original = LocalStatusRecord(articleID: "article-1", read: true, starred: false, lastModified: Date(timeIntervalSince1970: 1_000))
		let record = original.makeCKRecord(zoneID: zoneID)

		#expect(record.recordType == LocalStatusRecord.recordType)
		#expect(record.recordID.recordName == LocalStatusRecord.recordName(for: "article-1"))
		#expect(record[LocalStatusRecord.Fields.articleID] as? String == "article-1")
		#expect(record[LocalStatusRecord.Fields.read] as? String == "1")
		#expect(record[LocalStatusRecord.Fields.starred] as? String == "0")

		let decoded = try #require(LocalStatusRecord(record: record))
		#expect(decoded == original)
	}

	@Test func decodeRejectsWrongRecordType() {
		let record = CKRecord(recordType: "SomethingElse", recordID: CKRecord.ID(recordName: "x", zoneID: zoneID))
		#expect(LocalStatusRecord(record: record) == nil)
	}

	@Test func decodeRejectsMissingArticleID() {
		let record = CKRecord(recordType: LocalStatusRecord.recordType, recordID: CKRecord.ID(recordName: "x", zoneID: zoneID))
		record[LocalStatusRecord.Fields.read] = "1"
		#expect(LocalStatusRecord(record: record) == nil)
	}

	@Test func decodeFallsBackToModificationDate() throws {
		let record = CKRecord(recordType: LocalStatusRecord.recordType, recordID: CKRecord.ID(recordName: "x", zoneID: zoneID))
		record[LocalStatusRecord.Fields.articleID] = "article-2"
		let decoded = try #require(LocalStatusRecord(record: record))
		#expect(decoded.read == false)
		#expect(decoded.starred == false)
	}

	@Test func conflictResolutionIsLatestWins() {
		let older = LocalStatusRecord(articleID: "a", read: false, starred: false, lastModified: Date(timeIntervalSince1970: 100))
		let newer = LocalStatusRecord(articleID: "a", read: true, starred: true, lastModified: Date(timeIntervalSince1970: 200))

		#expect(LocalStatusRecord.resolve(local: older, remote: newer) == newer)
		#expect(LocalStatusRecord.resolve(local: newer, remote: older) == newer)
	}

	@Test func conflictResolutionPrefersRemoteOnTie() {
		let local = LocalStatusRecord(articleID: "a", read: true, starred: false, lastModified: Date(timeIntervalSince1970: 100))
		let remote = LocalStatusRecord(articleID: "a", read: false, starred: true, lastModified: Date(timeIntervalSince1970: 100))

		#expect(LocalStatusRecord.resolve(local: local, remote: remote) == remote)
	}

	@Test func remoteShouldBeApplied() {
		let local = LocalStatusRecord(articleID: "a", read: false, starred: false, lastModified: Date(timeIntervalSince1970: 200))
		let olderRemote = LocalStatusRecord(articleID: "a", read: true, starred: false, lastModified: Date(timeIntervalSince1970: 100))
		let newerRemote = LocalStatusRecord(articleID: "a", read: true, starred: false, lastModified: Date(timeIntervalSince1970: 300))
		let tieRemote = LocalStatusRecord(articleID: "a", read: true, starred: false, lastModified: Date(timeIntervalSince1970: 200))

		#expect(!local.remoteShouldBeApplied(remote: olderRemote))
		#expect(local.remoteShouldBeApplied(remote: newerRemote))
		#expect(local.remoteShouldBeApplied(remote: tieRemote))
	}

}
