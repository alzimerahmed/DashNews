//
//  KeywordHighlighter.swift
//  DashNews
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation

/// Wraps keyword matches in article HTML with <mark> tags for highlighting.
/// Feature #2 — highlight rules. Replacements happen only in text segments
/// between HTML tags, so markup is never corrupted, and all keywords are
/// wrapped in a single pass so inserted tags are never re-matched.
nonisolated enum KeywordHighlighter {

	static let markOpenTag = "<mark class=\"nnwKeywordHighlight\">"
	static let markCloseTag = "</mark>"

	/// Returns the HTML with each keyword match wrapped in a <mark> tag.
	/// Matching is case-insensitive; empty keywords are ignored.
	static func highlightedHTML(_ html: String, keywords: [String]) -> String {
		let effectiveKeywords = keywords
			.map { $0.trimmingWhitespace }
			.filter { !$0.isEmpty }
		guard !effectiveKeywords.isEmpty, !html.isEmpty else {
			return html
		}

		guard let tagRegex = try? NSRegularExpression(pattern: "<[^>]*>", options: []) else {
			return html
		}

		let matches = tagRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
		var result = ""
		var previousEnd = html.startIndex
		for match in matches {
			guard let tagRange = Range(match.range, in: html) else {
				continue
			}
			result += markKeywords(in: String(html[previousEnd..<tagRange.lowerBound]), keywords: effectiveKeywords)
			result += html[tagRange]
			previousEnd = tagRange.upperBound
		}
		result += markKeywords(in: String(html[previousEnd...]), keywords: effectiveKeywords)
		return result
	}
}

// MARK: - Private

private extension KeywordHighlighter {

	/// Wraps keyword matches in plain (non-tag) HTML text with <mark> tags.
	static func markKeywords(in text: String, keywords: [String]) -> String {
		let patterns = keywords.map { NSRegularExpression.escapedPattern(for: $0) }
		let combinedPattern = "(?i)(" + patterns.joined(separator: "|") + ")"
		guard let regex = try? NSRegularExpression(pattern: combinedPattern, options: []) else {
			return text
		}
		let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)).reversed()
		var result = text
		for match in matches {
			guard let matchRange = Range(match.range, in: result) else {
				continue
			}
			result.replaceSubrange(matchRange, with: markOpenTag + result[matchRange] + markCloseTag)
		}
		return result
	}
}
