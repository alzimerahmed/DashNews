//
//  KeySentenceHighlighterTests.swift
//  DashNewsTests
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import XCTest
@testable import DashNews

final class KeySentenceHighlighterTests: XCTestCase {

	func testWrapsSentenceInPlainText() {
		let html = "The council voted today. Cats sleep a lot."
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["The council voted today."])
		XCTAssertEqual(result, "<mark class=\"nnwKeyPoint\">The council voted today.</mark> Cats sleep a lot.")
	}

	func testWrapsSentenceInTextBetweenTags() {
		let html = "<p>The council voted today.</p><p>Cats sleep a lot.</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["The council voted today."])
		XCTAssertEqual(result, "<p><mark class=\"nnwKeyPoint\">The council voted today.</mark></p><p>Cats sleep a lot.</p>")
	}

	func testDoesNotMatchInsideTags() {
		let html = "<p class=\"council vote\">other text</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["council vote"])
		XCTAssertEqual(result, html)
	}

	func testMarksOnlyFirstOccurrence() {
		let html = "<p>Rates rose sharply. Rates rose sharply.</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["Rates rose sharply."])
		let occurrences = result.components(separatedBy: "<mark class=\"nnwKeyPoint\">").count - 1
		XCTAssertEqual(occurrences, 1)
	}

	func testMultipleSentencesBothMarked() {
		let html = "<p>Rates rose sharply today.</p><p>Analysts expect more increases.</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: [
			"Rates rose sharply today.",
			"Analysts expect more increases."
		])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeyPoint\">Rates rose sharply today.</mark>"))
		XCTAssertTrue(result.contains("<mark class=\"nnwKeyPoint\">Analysts expect more increases.</mark>"))
	}

	func testFlexibleWhitespaceMatching() {
		// The plain-text sentence has single spaces; the HTML segment has a
		// newline and extra spaces between words.
		let html = "<p>Rates rose\n  sharply   today.</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["Rates rose sharply today."])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeyPoint\">Rates rose\n  sharply   today.</mark>"))
	}

	func testLongSentenceSplitByTagMarksAnchor() {
		// The full sentence is split by an inline tag after the leading
		// anchor words, so only the anchor is marked.
		let html = "<p>The council voted early on Tuesday to approve <em>the</em> plan.</p>"
		let sentence = "The council voted early on Tuesday to approve the plan."
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: [sentence])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeyPoint\">The council voted early on Tuesday to approve</mark>"))
	}

	func testDuplicateSentencesAreNotMarkedTwice() {
		let html = "<p>Rates rose sharply.</p><p>Rates rose sharply.</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["Rates rose sharply.", "Rates rose sharply."])
		let occurrences = result.components(separatedBy: "<mark class=\"nnwKeyPoint\">").count - 1
		XCTAssertEqual(occurrences, 1)
	}

	func testEmptyInputsReturnOriginal() {
		let html = "<p>text</p>"
		XCTAssertEqual(KeySentenceHighlighter.highlightedHTML(html, keySentences: []), html)
		XCTAssertEqual(KeySentenceHighlighter.highlightedHTML("", keySentences: ["Rates rose."]), "")
		XCTAssertEqual(KeySentenceHighlighter.highlightedHTML(html, keySentences: ["   "]), html)
	}

	func testSentenceWithRegexCharacters() {
		let html = "<p>Inflation hit 3.5% (a record) in June.</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["Inflation hit 3.5% (a record) in June."])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeyPoint\">Inflation hit 3.5% (a record) in June.</mark>"))
	}

	func testEntityEncodedApostropheMatches() {
		// Needle comes from decoded text ("company's"); the HTML segment
		// holds the entity-encoded form.
		let html = "<p>The company&#8217;s earnings beat estimates.</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["The company's earnings beat estimates."])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeyPoint\">The company&#8217;s earnings beat estimates.</mark>"))
	}

	func testAmpersandEntityMatches() {
		let html = "<p>Trial &amp; error shaped the rollout.</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["Trial & error shaped the rollout."])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeyPoint\">Trial &amp; error shaped the rollout.</mark>"))
	}

	func testNbspEntityMatchesWhitespace() {
		let html = "<p>Rates&nbsp;rose sharply.</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["Rates rose sharply."])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeyPoint\">Rates&nbsp;rose sharply.</mark>"))
	}

	func testAngleBracketInsideQuotedAttributeIsNotText() {
		// A > inside a quoted attribute value must not split the tag, so
		// attribute text can never receive a mark.
		let html = "<p><a href=\"https://example.com\" title=\"read > more\">Rates rose sharply.</a></p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["more"])
		XCTAssertEqual(result, html)
	}

	func testMarksTextAfterQuotedAttributeWithAngleBracket() {
		let html = "<a href=\"https://example.com\" title=\"read > more\">Rates rose sharply.</a>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["Rates rose sharply."])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeyPoint\">Rates rose sharply.</mark>"))
		XCTAssertTrue(result.contains("title=\"read > more\""))
	}

	func testScriptAndStyleContentIsNotMarked() {
		let html = "<p>Rates rose sharply.</p><script>var x = 'var x';</script><style>.article { color: red; }</style>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: ["Rates rose sharply.", "var x"])
		XCTAssertTrue(result.contains("<mark class=\"nnwKeyPoint\">Rates rose sharply.</mark>"))
		XCTAssertTrue(result.contains("<script>var x = 'var x';</script>"))
		XCTAssertEqual(result.components(separatedBy: "<mark class=\"nnwKeyPoint\">").count - 1, 1)
	}

	func testSharedPrefixAnchorDoesNotNestInsideEarlierMark() {
		// The second sentence shares the first's 8-word anchor; after the
		// first is fully marked the anchor must not match inside that mark.
		let html = "<p>The council voted early on Tuesday to approve the transit plan.</p>"
		let result = KeySentenceHighlighter.highlightedHTML(html, keySentences: [
			"The council voted early on Tuesday to approve the transit plan.",
			"The council voted early on Tuesday to approve the budget."
		])
		XCTAssertEqual(result.components(separatedBy: "<mark").count - 1, 1)
		XCTAssertFalse(result.contains("<mark class=\"nnwKeyPoint\"><mark"))
	}
}
