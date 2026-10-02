//
//  KeywordRuleMatcherTests.swift
//  DashNewsTests
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import XCTest
import Articles
@testable import DashNews

@MainActor final class KeywordRuleMatcherTests: XCTestCase {

	private func makeArticle(title: String?, summary: String? = nil, contentText: String? = nil) -> Article {
		let status = ArticleStatus(articleID: "id", read: false, starred: false, dateArrived: Date())
		return Article(accountID: "account", articleID: "id", feedID: "feed", uniqueID: "unique", title: title, contentHTML: nil, contentText: contentText, markdown: nil, url: nil, externalURL: nil, summary: summary, imageURL: nil, datePublished: nil, dateModified: nil, authors: nil, status: status)
	}

	private func makeRule(keyword: String, action: KeywordRuleAction) -> KeywordRule {
		KeywordRule(feedID: "feed", keyword: keyword, action: action)
	}

	// MARK: Hide rules

	func testHideRuleMatchesTitleCaseInsensitively() {
		let article = makeArticle(title: "Breaking Crypto News")
		let rules = [makeRule(keyword: "crypto", action: .hide)]
		XCTAssertTrue(KeywordRuleMatcher.shouldHide(article: article, rules: rules))
	}

	func testHideRuleMatchesSummary() {
		let article = makeArticle(title: "Title", summary: "Sponsored content ahead")
		let rules = [makeRule(keyword: "sponsored", action: .hide)]
		XCTAssertTrue(KeywordRuleMatcher.shouldHide(article: article, rules: rules))
	}

	func testHideRuleMatchesContentText() {
		let article = makeArticle(title: "Title", contentText: "The word lottery appears here")
		let rules = [makeRule(keyword: "LOTTERY", action: .hide)]
		XCTAssertTrue(KeywordRuleMatcher.shouldHide(article: article, rules: rules))
	}

	func testNoMatchDoesNotHide() {
		let article = makeArticle(title: "Unrelated headline")
		let rules = [makeRule(keyword: "crypto", action: .hide)]
		XCTAssertFalse(KeywordRuleMatcher.shouldHide(article: article, rules: rules))
	}

	func testEmptyRulesNeverHide() {
		let article = makeArticle(title: "Crypto headline")
		XCTAssertFalse(KeywordRuleMatcher.shouldHide(article: article, rules: []))
	}

	func testHighlightRuleDoesNotHide() {
		let article = makeArticle(title: "Crypto headline")
		let rules = [makeRule(keyword: "crypto", action: .highlight)]
		XCTAssertFalse(KeywordRuleMatcher.shouldHide(article: article, rules: rules))
	}

	func testWhitespaceOnlyKeywordDoesNotHide() {
		let article = makeArticle(title: "Anything")
		let rules = [makeRule(keyword: "   ", action: .hide)]
		XCTAssertFalse(KeywordRuleMatcher.shouldHide(article: article, rules: rules))
	}

	// MARK: Match helper

	func testMatchesIsCaseInsensitive() {
		XCTAssertTrue(KeywordRuleMatcher.matches(keyword: "Swift", in: "learn SWIFT today"))
		XCTAssertFalse(KeywordRuleMatcher.matches(keyword: "swift", in: "no match here"))
	}

	func testMatchesEmptyKeywordIsFalse() {
		XCTAssertFalse(KeywordRuleMatcher.matches(keyword: "", in: "anything"))
	}
}
