//
//  ExtractiveSummarizerTests.swift
//  DashNewsTests
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import XCTest
@testable import DashNews

final class ExtractiveSummarizerTests: XCTestCase {

	/// Fixture where the topic sentences are unambiguous: "transit plan"
	/// sentences dominate the term-frequency scoring and sit at indices
	/// 0, 2, and 4.
	private let transitArticle = """
		The city council approved the new transit plan on Tuesday. \
		Cats sleep a lot during the day. \
		The transit plan includes three new rail lines across the city. \
		My favorite sandwich is turkey with mustard. \
		Officials say the transit plan will reduce traffic downtown significantly.
		"""

	func testEmptyContentReturnsNil() async {
		let summarizer = ExtractiveSummarizer()
		let result = await summarizer.summarize(title: nil, contentText: "")
		XCTAssertNil(result)
	}

	func testShortContentReturnsNil() async {
		let summarizer = ExtractiveSummarizer()
		let result = await summarizer.summarize(title: nil, contentText: "Short note.")
		XCTAssertNil(result)
	}

	func testArticleWithTooFewSentencesReturnsNil() async {
		// Long enough to pass the character gate, but only two sentences —
		// summarizing wouldn't shorten it.
		let text = """
			The city council approved a sweeping new transit plan late on Tuesday evening after months of public hearings and heated debate in chambers. \
			The plan includes three new rail lines crossing the downtown core, with construction expected to begin next spring.
			"""
		let summarizer = ExtractiveSummarizer()
		let result = await summarizer.summarize(title: nil, contentText: text)
		XCTAssertNil(result)
	}

	func testSummaryPicksHighestScoredSentencesInOriginalOrder() async throws {
		let summarizer = ExtractiveSummarizer()
		let result = await summarizer.summarize(title: nil, contentText: transitArticle)
		let summary = try XCTUnwrap(result)

		let sentences = [
			"The city council approved the new transit plan on Tuesday.",
			"The transit plan includes three new rail lines across the city.",
			"Officials say the transit plan will reduce traffic downtown significantly."
		]
		for sentence in sentences {
			XCTAssertTrue(summary.contains(sentence), "summary missing expected sentence: \(sentence)")
		}
		XCTAssertFalse(summary.contains("Cats sleep"))
		XCTAssertFalse(summary.contains("sandwich"))

		// Original document order preserved.
		let firstRange = summary.range(of: "The city council")
		let secondRange = summary.range(of: "The transit plan includes")
		let thirdRange = summary.range(of: "Officials say")
		XCTAssertNotNil(firstRange)
		XCTAssertNotNil(secondRange)
		XCTAssertNotNil(thirdRange)
		if let firstRange, let secondRange, let thirdRange {
			XCTAssertTrue(firstRange.lowerBound < secondRange.lowerBound)
			XCTAssertTrue(secondRange.lowerBound < thirdRange.lowerBound)
		}
	}

	func testSummaryRespectsCharacterCap() async throws {
		let summarizer = ExtractiveSummarizer(maxSentenceCount: 3, maxCharacterCount: 80)
		let result = await summarizer.summarize(title: nil, contentText: transitArticle)
		let summary = try XCTUnwrap(result)
		XCTAssertLessThanOrEqual(summary.count, 80)
	}

	func testKeySentencesReturnsTopSentencesInDocumentOrder() {
		let summarizer = ExtractiveSummarizer()
		let keySentences = summarizer.keySentences(in: transitArticle, maxCount: 2)

		XCTAssertEqual(keySentences.count, 2)
		// The two top scorers must appear in document order.
		if keySentences.count == 2 {
			let firstIndex = transitArticle.range(of: keySentences[0])
			let secondIndex = transitArticle.range(of: keySentences[1])
			XCTAssertNotNil(firstIndex)
			XCTAssertNotNil(secondIndex)
			if let firstIndex, let secondIndex {
				XCTAssertTrue(firstIndex.lowerBound < secondIndex.lowerBound)
			}
		}
		for sentence in keySentences {
			XCTAssertTrue(sentence.contains("transit") || sentence.contains("city council"))
		}
	}

	func testKeySentencesEmptyInput() {
		let summarizer = ExtractiveSummarizer()
		XCTAssertTrue(summarizer.keySentences(in: "").isEmpty)
	}

	func testScoredSentencesCoverEverySentenceInOrder() {
		let summarizer = ExtractiveSummarizer()
		let scored = summarizer.scoredSentences(in: transitArticle)

		XCTAssertEqual(scored.count, 5)
		XCTAssertEqual(scored.map(\.index), [0, 1, 2, 3, 4])
	}

	func testTitleOverlapBoostsScore() {
		let summarizer = ExtractiveSummarizer()
		let scored = summarizer.scoredSentences(in: transitArticle, title: "Transit plan approved")

		let transitScore = scored[2].score // "The transit plan includes…"
		let unrelatedScore = scored[3].score // "My favorite sandwich…"
		XCTAssertGreaterThan(transitScore, unrelatedScore)
	}
}
