//
//  ExtractiveSummarizer.swift
//  DashNews
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import NaturalLanguage

/// A sentence in an article with its extractive score and document position.
nonisolated struct ScoredSentence: Sendable {

	let text: String
	let score: Double
	let index: Int
}

/// Deterministic extractive summarizer. Feature #9 — the fallback for devices
/// where Apple Foundation Models isn't available, and the sentence scorer
/// behind Feature #8 key-point highlighting.
///
/// Sentences are segmented with NLTagger and scored on normalized term
/// frequency, position in the article, and overlap with the title, with a
/// length normalization so very short sentences don't win. The top-scoring
/// sentences are returned in their original document order.
nonisolated struct ExtractiveSummarizer {

	static let defaultMaxSentenceCount = 3
	static let defaultMaxCharacterCount = 700
	static let minimumContentLength = 240
	static let minimumSentenceWordCount = 4

	let maxSentenceCount: Int
	let maxCharacterCount: Int

	init(maxSentenceCount: Int = ExtractiveSummarizer.defaultMaxSentenceCount, maxCharacterCount: Int = ExtractiveSummarizer.defaultMaxCharacterCount) {
		self.maxSentenceCount = maxSentenceCount
		self.maxCharacterCount = maxCharacterCount
	}

	/// The highest-scored sentences in their original document order.
	/// No minimum-length gate, so this can mark key sentences in articles of
	/// any length.
	func keySentences(in contentText: String, title: String? = nil, maxCount: Int = ExtractiveSummarizer.defaultMaxSentenceCount) -> [String] {
		scoredSentences(in: contentText, title: title)
			.sorted(by: Self.scoreOrdering)
			.prefix(maxCount)
			.sorted { $0.index < $1.index }
			.map(\.text)
	}

	/// Every detected sentence with its score, in document order.
	func scoredSentences(in contentText: String, title: String? = nil) -> [ScoredSentence] {
		let sentences = Self.sentences(in: contentText)
		guard !sentences.isEmpty else {
			return []
		}
		let frequencies = Self.normalizedTermFrequencies(in: sentences)
		let titleWords = Set(Self.contentWords(in: title ?? ""))
		var scored = [ScoredSentence]()
		scored.reserveCapacity(sentences.count)
		for (index, sentence) in sentences.enumerated() {
			let score = Self.score(sentence: sentence, index: index, frequencies: frequencies, titleWords: titleWords)
			scored.append(ScoredSentence(text: sentence, score: score, index: index))
		}
		return scored
	}
}

// MARK: - ArticleSummarizing

extension ExtractiveSummarizer: ArticleSummarizing {

	func summarize(title: String?, contentText: String) async -> String? {
		let trimmed = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.count >= Self.minimumContentLength else {
			return nil
		}

		let ranked = scoredSentences(in: trimmed, title: title).sorted(by: Self.scoreOrdering)
		guard ranked.count > maxSentenceCount else {
			// A summary containing every sentence wouldn't shorten the article.
			return nil
		}

		// Take top-scored sentences while respecting the character cap; the
		// single best sentence is always kept even when it exceeds the cap
		// (truncated below).
		var chosen = [ScoredSentence]()
		var length = 0
		for sentence in ranked.prefix(maxSentenceCount) {
			let separatorLength = chosen.isEmpty ? 0 : 1
			let wouldBe = length + separatorLength + sentence.text.count
			if chosen.isEmpty || wouldBe <= maxCharacterCount {
				chosen.append(sentence)
				length = wouldBe
			}
		}

		let summary = chosen.sorted { $0.index < $1.index }.map(\.text).joined(separator: " ")
		guard !summary.isEmpty else {
			return nil
		}
		if summary.count > maxCharacterCount {
			return String(summary.prefix(maxCharacterCount))
		}
		return summary
	}
}

// MARK: - Private

private extension ExtractiveSummarizer {

	static let positionWeight = 0.4
	static let titleWeight = 0.5

	/// Higher score first; ties go to the earlier sentence so results are
	/// fully deterministic.
	static func scoreOrdering(_ lhs: ScoredSentence, _ rhs: ScoredSentence) -> Bool {
		if lhs.score != rhs.score {
			return lhs.score > rhs.score
		}
		return lhs.index < rhs.index
	}

	static func score(sentence: String, index: Int, frequencies: [String: Double], titleWords: Set<String>) -> Double {
		let words = contentWords(in: sentence)
		guard words.count >= minimumSentenceWordCount else {
			return 0
		}

		let frequencyScore = words.reduce(0.0) { $0 + (frequencies[$1] ?? 0) } / Double(words.count)
		let positionScore = 1.0 / Double(index + 1)
		let titleScore: Double
		if titleWords.isEmpty {
			titleScore = 0
		} else {
			let overlapCount = words.filter { titleWords.contains($0) }.count
			titleScore = Double(overlapCount) / Double(titleWords.count)
		}
		return frequencyScore + positionWeight * positionScore + titleWeight * titleScore
	}

	static func sentences(in text: String) -> [String] {
		guard !text.isEmpty else {
			return []
		}
		var sentences = [String]()
		let tagger = NLTagger(tagSchemes: [.tokenType])
		tagger.string = text
		tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .tokenType) { _, range in
			let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
			if !sentence.isEmpty {
				sentences.append(sentence)
			}
			return true
		}
		return sentences
	}

	/// Lowercased word tokens with common English stop words removed.
	static func contentWords(in text: String) -> [String] {
		guard !text.isEmpty else {
			return []
		}
		var words = [String]()
		let tagger = NLTagger(tagSchemes: [.tokenType])
		tagger.string = text
		let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
		tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .tokenType, options: options) { _, range in
			let word = text[range].lowercased()
			if !stopWords.contains(word) {
				words.append(word)
			}
			return true
		}
		return words
	}

	static func normalizedTermFrequencies(in sentences: [String]) -> [String: Double] {
		var counts = [String: Int]()
		for sentence in sentences {
			for word in contentWords(in: sentence) {
				counts[word, default: 0] += 1
			}
		}
		guard let maxCount = counts.values.max(), maxCount > 0 else {
			return [:]
		}
		return counts.mapValues { Double($0) / Double(maxCount) }
	}

	static let stopWords: Set<String> = [
		"a", "an", "the", "and", "or", "but", "if", "of", "at", "by", "for",
		"with", "about", "to", "from", "in", "on", "is", "are", "was", "were",
		"be", "been", "it", "its", "that", "this", "as", "not", "no", "so",
		"we", "you", "i", "he", "she", "they", "his", "her", "their", "our",
		"your", "my", "said", "says", "say", "will", "would", "could",
		"should", "has", "have", "had", "do", "does", "did"
	]
}
