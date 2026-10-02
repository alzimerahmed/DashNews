//
//  FeedIntelligenceStoreTests.swift
//  DashNewsTests
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import XCTest
@testable import DashNews

@MainActor final class FeedIntelligenceStoreTests: XCTestCase {

	// XCTest calls setUp/tearDown from a nonisolated context; all access is
	// still on the main thread, so the unsafe annotation is sound here.
	nonisolated(unsafe) private var fileURL: URL!

	override func setUp() {
		super.setUp()
		fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("feed-intelligence-\(UUID().uuidString).json")
	}

	override func tearDown() {
		try? FileManager.default.removeItem(at: fileURL)
		super.tearDown()
	}

	func testUnknownFeedDefaultsToOff() {
		let store = FeedIntelligenceStore(fileURL: fileURL)
		XCTAssertFalse(store.highlightKeyPoints(forFeedID: "feed1"))
		XCTAssertEqual(store.settings(forFeedID: "feed1"), .off)
	}

	func testSetPersistsAcrossStoreRecreation() {
		let store = FeedIntelligenceStore(fileURL: fileURL)
		store.setHighlightKeyPoints(true, forFeedID: "feed1")

		let reloadedStore = FeedIntelligenceStore(fileURL: fileURL)
		XCTAssertTrue(reloadedStore.highlightKeyPoints(forFeedID: "feed1"))
	}

	func testFlagsAreIsolatedPerFeed() {
		let store = FeedIntelligenceStore(fileURL: fileURL)
		store.setHighlightKeyPoints(true, forFeedID: "feed1")

		XCTAssertTrue(store.highlightKeyPoints(forFeedID: "feed1"))
		XCTAssertFalse(store.highlightKeyPoints(forFeedID: "feed2"))
	}

	func testSettingBackToDefaultRemovesEntry() {
		let store = FeedIntelligenceStore(fileURL: fileURL)
		store.setHighlightKeyPoints(true, forFeedID: "feed1")
		store.setHighlightKeyPoints(false, forFeedID: "feed1")

		XCTAssertFalse(store.highlightKeyPoints(forFeedID: "feed1"))
		XCTAssertNil(store.settingsByFeedID["feed1"])
	}

	func testCorruptFileLoadsAsDefaults() throws {
		try Data("not json".utf8).write(to: fileURL)

		let store = FeedIntelligenceStore(fileURL: fileURL)

		XCTAssertTrue(store.settingsByFeedID.isEmpty)
		XCTAssertFalse(store.highlightKeyPoints(forFeedID: "feed1"))
	}
}
