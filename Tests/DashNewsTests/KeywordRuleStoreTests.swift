//
//  KeywordRuleStoreTests.swift
//  DashNewsTests
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import XCTest
@testable import DashNews

@MainActor final class KeywordRuleStoreTests: XCTestCase {

	// XCTest calls setUp/tearDown from a nonisolated context; all access is
	// still on the main thread, so the unsafe annotation is sound here.
	nonisolated(unsafe) private var fileURL: URL!

	override func setUp() {
		super.setUp()
		fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("keyword-rules-\(UUID().uuidString).json")
	}

	override func tearDown() {
		try? FileManager.default.removeItem(at: fileURL)
		super.tearDown()
	}

	func testAddPersistsAcrossStoreRecreation() {
		let store = KeywordRuleStore(fileURL: fileURL)
		store.add(feedID: "feed1", keyword: "crypto", action: .hide)

		let reloadedStore = KeywordRuleStore(fileURL: fileURL)
		XCTAssertEqual(reloadedStore.rules.count, 1)
		XCTAssertEqual(reloadedStore.rules.first?.feedID, "feed1")
		XCTAssertEqual(reloadedStore.rules.first?.keyword, "crypto")
		XCTAssertEqual(reloadedStore.rules.first?.action, .hide)
	}

	func testAddSameFeedKeywordActionDoesNotDuplicate() throws {
		let store = KeywordRuleStore(fileURL: fileURL)
		let first = try XCTUnwrap(store.add(feedID: "feed1", keyword: "crypto", action: .hide))
		let second = try XCTUnwrap(store.add(feedID: "feed1", keyword: "crypto", action: .hide))

		XCTAssertEqual(store.rules.count, 1)
		XCTAssertEqual(first.id, second.id)
	}

	func testSameKeywordDifferentActionIsAllowed() {
		let store = KeywordRuleStore(fileURL: fileURL)
		store.add(feedID: "feed1", keyword: "crypto", action: .hide)
		store.add(feedID: "feed1", keyword: "crypto", action: .highlight)

		XCTAssertEqual(store.rules.count, 2)
	}

	func testAddEmptyKeywordIsIgnored() {
		let store = KeywordRuleStore(fileURL: fileURL)
		store.add(feedID: "feed1", keyword: "   ", action: .hide)

		XCTAssertTrue(store.rules.isEmpty)
	}

	func testRemoveDeletesRule() throws {
		let store = KeywordRuleStore(fileURL: fileURL)
		let rule = try XCTUnwrap(store.add(feedID: "feed1", keyword: "crypto", action: .hide))

		store.remove(id: rule.id)

		XCTAssertTrue(store.rules.isEmpty)
	}

	func testRulesForFeedFiltersByFeed() {
		let store = KeywordRuleStore(fileURL: fileURL)
		store.add(feedID: "feed1", keyword: "crypto", action: .hide)
		store.add(feedID: "feed2", keyword: "lottery", action: .hide)

		XCTAssertEqual(store.rules(forFeedID: "feed1").count, 1)
		XCTAssertEqual(store.hideRules(forFeedID: "feed2").count, 1)
		XCTAssertTrue(store.highlightKeywords(forFeedID: "feed1").isEmpty)
	}

	func testHighlightKeywordsReturnsKeywordsOnly() {
		let store = KeywordRuleStore(fileURL: fileURL)
		store.add(feedID: "feed1", keyword: "swift", action: .highlight)
		store.add(feedID: "feed1", keyword: "objc", action: .highlight)
		store.add(feedID: "feed1", keyword: "crypto", action: .hide)

		XCTAssertEqual(Set(store.highlightKeywords(forFeedID: "feed1")), Set(["swift", "objc"]))
	}

	func testCorruptFileLoadsAsEmpty() throws {
		try Data("not json".utf8).write(to: fileURL)

		let store = KeywordRuleStore(fileURL: fileURL)

		XCTAssertTrue(store.rules.isEmpty)
	}
}
