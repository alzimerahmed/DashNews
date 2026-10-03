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
		XCTAssertEqual(result, "Breaking <mark class=\"nnwKeywordHighlight\">crypto</mark> news today")
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

	func testGreaterThanInsideQuotedAttributeDoesNotSplitTag() {
		// `>` inside a quoted attribute must not end the tag — the keyword
		// inside the attribute value must not be marked.
		let html = "<a title=\"2 > 1 crypto\">link</a>"
		let result = KeywordHighlighter.highlightedHTML(html, keywords: ["crypto"])
		XCTAssertEqual(result, html)
	}

	func testDoesNotMarkInsideScript() {
		let html = "<script>var crypto = 1;</script><p>crypto</p>"
		let result = KeywordHighlighter.highlightedHTML(html, keywords: ["crypto"])
		XCTAssertEqual(result, "<script>var crypto = 1;</script><p><mark class=\"nnwKeywordHighlight\">crypto</mark></p>")
	}

	func testDoesNotMarkInsideStyle() {
		let html = "<style>.crypto { color: red; }</style>crypto"
		let result = KeywordHighlighter.highlightedHTML(html, keywords: ["crypto"])
		XCTAssertEqual(result, "<style>.crypto { color: red; }</style><mark class=\"nnwKeywordHighlight\">crypto</mark>")
	}

	func testDoesNotMarkInsideExistingMark() {
		let html = "<mark class=\"other\">crypto</mark> crypto"
		let result = KeywordHighlighter.highlightedHTML(html, keywords: ["crypto"])
		XCTAssertEqual(result, "<mark class=\"other\">crypto</mark> <mark class=\"nnwKeywordHighlight\">crypto</mark>")
	}

	func testCommentDoesNotSplitSegments() {
		// `>` inside a comment must not end the tag scan.
		let html = "<!-- > crypto -->crypto"
		let result = KeywordHighlighter.highlightedHTML(html, keywords: ["crypto"])
		XCTAssertEqual(result, "<!-- > crypto --><mark class=\"nnwKeywordHighlight\">crypto</mark>")
	}
}
