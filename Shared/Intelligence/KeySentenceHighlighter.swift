//
//  KeySentenceHighlighter.swift
//  DashNews
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation

/// Wraps key sentences in article HTML with <mark> tags for highlighting.
/// Feature #8 — NewsBlur-style key-point highlighting. Replacements happen
/// only in text segments between HTML tags, so markup is never corrupted,
/// and each sentence is marked at its first occurrence only.
nonisolated enum KeySentenceHighlighter {

	static let markOpenTag = "<mark class=\"nnwKeyPoint\">"
	static let markCloseTag = "</mark>"

	/// Number of leading sentence words used as a fallback anchor when the
	/// full sentence doesn't appear contiguously in a single text segment —
	/// for example when inline markup splits it.
	static let anchorWordCount = 8

	/// Returns the HTML with the first occurrence of each key sentence
	/// wrapped in a <mark class="nnwKeyPoint"> tag.
	static func highlightedHTML(_ html: String, keySentences: [String]) -> String {
		let sentences = keySentences
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
		guard !sentences.isEmpty, !html.isEmpty else {
			return html
		}

		var result = html
		var placedNeedles = Set<String>()
		for sentence in sentences {
			for needle in needles(for: sentence) where !placedNeedles.contains(needle) {
				guard let marked = markFirstOccurrence(in: result, needle: needle) else {
					continue
				}
				result = marked
				placedNeedles.insert(needle)
				break
			}
		}
		return result
	}
}

// MARK: - Private

private extension KeySentenceHighlighter {

	/// Candidate needles for a sentence, longest first: the full sentence,
	/// then a leading anchor so a sentence split by inline markup still gets
	/// its opening words marked.
	static func needles(for sentence: String) -> [String] {
		let normalized = normalizeWhitespace(sentence)
		let words = normalized.components(separatedBy: " ").filter { !$0.isEmpty }
		var needles = [normalized]
		if words.count > anchorWordCount {
			needles.append(words.prefix(anchorWordCount).joined(separator: " "))
		}
		return needles
	}

	static func normalizeWhitespace(_ text: String) -> String {
		text.components(separatedBy: .whitespacesAndNewlines)
			.filter { !$0.isEmpty }
			.joined(separator: " ")
	}

	/// A case-insensitive regex matching the needle with flexible whitespace
	/// between words — HTML text may contain newlines or runs of spaces where
	/// the plain-text source has single spaces.
	static func needleRegex(for needle: String) -> NSRegularExpression? {
		let escapedWords = needle
			.components(separatedBy: " ")
			.filter { !$0.isEmpty }
			.map { NSRegularExpression.escapedPattern(for: $0) }
		guard !escapedWords.isEmpty else {
			return nil
		}
		return try? NSRegularExpression(pattern: "(?i)" + escapedWords.joined(separator: "\\s+"), options: [])
	}

	/// Wraps the first occurrence of `needle` found in the text segments
	/// between HTML tags. Returns nil when the needle isn't found.
	static func markFirstOccurrence(in html: String, needle: String) -> String? {
		guard let tagRegex = try? NSRegularExpression(pattern: "<[^>]*>", options: []),
			  let regex = needleRegex(for: needle) else {
			return nil
		}

		let tagMatches = tagRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
		var previousEnd = html.startIndex
		for tagMatch in tagMatches {
			guard let tagRange = Range(tagMatch.range, in: html) else {
				continue
			}
			if let markedSegment = markFirstMatch(in: html[previousEnd..<tagRange.lowerBound], regex: regex) {
				return String(html[..<previousEnd]) + markedSegment + String(html[tagRange...])
			}
			previousEnd = tagRange.upperBound
		}
		if let markedSegment = markFirstMatch(in: html[previousEnd...], regex: regex) {
			return String(html[..<previousEnd]) + markedSegment
		}
		return nil
	}

	static func markFirstMatch(in segment: Substring, regex: NSRegularExpression) -> String? {
		let text = String(segment)
		guard !text.isEmpty else {
			return nil
		}
		guard let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
			  let matchRange = Range(match.range, in: text) else {
			return nil
		}
		return text.replacingCharacters(in: matchRange, with: markOpenTag + String(text[matchRange]) + markCloseTag)
	}
}
