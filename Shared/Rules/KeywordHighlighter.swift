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
/// between HTML tags, so markup is never corrupted. The tag scanner handles
/// `>` characters inside quoted attribute values and HTML comments — the same
/// strategy KeySentenceHighlighter uses — and text inside <script>/<style>
/// regions and inside previously inserted marks is never touched. All
/// keywords are matched with one combined regex compiled once per call.
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

		let combinedPattern = "(?i)(" + effectiveKeywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")"
		guard let keywordRegex = try? NSRegularExpression(pattern: combinedPattern, options: []),
			  let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: []) else {
			return html
		}

		let tagMatches = tagRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
		var result = ""
		var previousEnd = html.startIndex
		var markDepth = 0
		var suppressed = false
		for match in tagMatches {
			guard let tagRange = Range(match.range, in: html) else {
				continue
			}
			let segment = html[previousEnd..<tagRange.lowerBound]
			if markDepth == 0 && !suppressed {
				result += markKeywords(in: String(segment), regex: keywordRegex)
			} else {
				// Suppressed regions are passed through unmarked — the
				// text must survive even though it isn't highlighted.
				result += segment
			}
			result += html[tagRange]
			updateState(for: html[tagRange], markDepth: &markDepth, suppressed: &suppressed)
			previousEnd = tagRange.upperBound
		}
		let tail = html[previousEnd...]
		if markDepth == 0 && !suppressed {
			result += markKeywords(in: String(tail), regex: keywordRegex)
		} else {
			result += tail
		}
		return result
	}
}

// MARK: - Private

private extension KeywordHighlighter {

	/// Matches whole HTML tags, respecting > characters inside single- or
	/// double-quoted attribute values, plus HTML comments. Same pattern as
	/// KeySentenceHighlighter.tagPattern.
	static let tagPattern = "(?:<!--[\\s\\S]*?-->|<(?:\"[^\"]*\"|'[^']*'|[^'\">]*)*>)"

	/// Wraps all keyword matches in plain (non-tag) HTML text with <mark>
	/// tags. The caller passes one pre-compiled combined regex so the
	/// pattern is built once per highlightedHTML call, not per segment.
	static func markKeywords(in text: String, regex: NSRegularExpression) -> String {
		let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)).reversed()
		var result = text
		for match in matches {
			guard let matchRange = Range(match.range, in: result) else {
				continue
			}
			let matchedText = String(result[matchRange])
			result.replaceSubrange(matchRange, with: markOpenTag + matchedText + markCloseTag)
		}
		return result
	}

	/// Tracks whether following text segments are inside a <mark>,
	/// <script>, or <style> region and therefore ineligible for marking.
	/// Same strategy as KeySentenceHighlighter.updateState.
	static func updateState(for tag: Substring, markDepth: inout Int, suppressed: inout Bool) {
		let lowered = tag.lowercased()
		if isMarkOpenTag(lowered) {
			markDepth += 1
			return
		}
		if isMarkCloseTag(lowered) {
			markDepth = max(0, markDepth - 1)
			return
		}
		if let name = tagName(of: tag), name == "script" || name == "style" {
			if isClosingTag(lowered) {
				suppressed = false
			} else if !lowered.hasSuffix("/>") {
				// Self-closing <script/> or <style/> never opens a region.
				suppressed = true
			}
		}
	}

	static func isMarkOpenTag(_ loweredTag: String) -> Bool {
		loweredTag.hasPrefix("<mark>") || loweredTag.hasPrefix("<mark ")
	}

	static func isMarkCloseTag(_ loweredTag: String) -> Bool {
		loweredTag.hasPrefix("</mark")
	}

	static func isClosingTag(_ loweredTag: String) -> Bool {
		loweredTag.dropFirst().first == "/"
	}

	static func tagName(of tag: Substring) -> String? {
		var content = tag.dropFirst() // drop "<"
		if content.first == "!" || content.first == "/" {
			content = content.dropFirst()
		}
		content = content.drop(while: { $0 == " " })
		let name = content.prefix(while: { $0.isLetter || $0.isNumber })
		guard !name.isEmpty else {
			return nil
		}
		return String(name).lowercased()
	}
}
