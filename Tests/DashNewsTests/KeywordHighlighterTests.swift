//
//  KeywordHighlighterTests.swift
//  DashNewsTests
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import XCTest
@testable import DashNews

final class KeywordHighlighterTests: XCTestCase {

	func testWrapsMatchInPlainText() {
		let result = KeywordHighlighter.highlightedHTML("Breaking crypto news today", keywords: ["crypto"])
		XCTAssertEqual(result, "<mark class=\"nnwKeywordHighlight\">crypto</mark>")
	}

	func testMatchIsCaseInsensitive() {
		let result = KeywordHighlighter.highlightedHTML("Breaking CRYPTO news", keywords: ["crypto"])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeywordHighlight\">CRYPTO</mark>"))
	}

	func testDoesNotMatchInsideTags() {
		let html = "<p class=\"crypto\">text</p>"
		let result = KeywordHighlighter.highlightedHTML(html, keywords: ["crypto"])
		XCTAssertEqual(result, "<p class=\"crypto\">text</p>")
	}

	func testMatchesInTextBetweenTags() {
		let html = "<p>crypto news</p>"
		let result = KeywordHighlighter.highlightedHTML(html, keywords: ["crypto"])
		XCTAssertEqual(result, "<p><mark class=\"nnwKeywordHighlight\">crypto</mark> news</p>")
	}

	func testMultipleKeywordsSinglePass() {
		let html = "swift and crypto"
		let result = KeywordHighlighter.highlightedHTML(html, keywords: ["swift", "crypto"])
		XCTAssertEqual(result, "<mark class=\"nnwKeywordHighlight\">swift</mark> and <mark class=\"nnwKeywordHighlight\">crypto</mark>")
	}

	func testKeywordHighlightDoesNotSelfMatchInsertedTags() {
		// The inserted class name contains "highlight" — a keyword "highlight"
		// must not wrap inside the inserted tag.
		let result = KeywordHighlighter.highlightedHTML("please highlight this", keywords: ["highlight"])
		XCTAssertEqual(result, "please <mark class=\"nnwKeywordHighlight\">highlight</mark> this")
	}

	func testEmptyKeywordsReturnsOriginal() {
		let html = "<p>text</p>"
		XCTAssertEqual(KeywordHighlighter.highlightedHTML(html, keywords: []), html)
	}

	func testWhitespaceKeywordsAreIgnored() {
		let html = "text"
		XCTAssertEqual(KeywordHighlighter.highlightedHTML(html, keywords: ["   "]), html)
	}

	func testRegexSpecialCharactersInKeywordAreEscaped() {
		let result = KeywordHighlighter.highlightedHTML("cost is 3.5 dollars (C++)", keywords: ["3.5", "C++"])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeywordHighlight\">3.5</mark>"))
		XCTAssertTrue(result.contains("<mark class=\"nnwKeywordHighlight\">C++</mark>"))
	}
}
