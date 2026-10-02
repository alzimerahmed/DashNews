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
/// only in text segments between HTML tags, so markup is never corrupted;
/// text inside <script>/<style> regions and inside previously inserted marks
/// is never touched, and each sentence is marked at its first occurrence only.
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
			let candidates = needles(for: sentence)
			for needle in candidates where !placedNeedles.contains(needle) {
				guard let marked = markFirstOccurrence(in: result, needle: needle) else {
					continue
				}
				result = marked
				// Record every needle for this sentence — including the
				// anchor — so a later sentence sharing the prefix can't mark
				// inside (or next to) the mark just placed.
				placedNeedles.formUnion(candidates)
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

	/// A case-insensitive regex matching the needle in raw HTML text.
	/// Whitespace between words is flexible (spaces, newlines, &nbsp; forms),
	/// and characters that commonly appear as entities (' & " – — … and
	/// non-breaking spaces inside words) map to alternations covering both
	/// the literal character and its entity spellings — needles come from
	/// decoded plain text while segments are raw HTML.
	static func needleRegex(for needle: String) -> NSRegularExpression? {
		let wordPatterns = needle
			.components(separatedBy: " ")
			.filter { !$0.isEmpty }
			.map(escapedWordPattern)
		guard !wordPatterns.isEmpty else {
			return nil
		}
		let separator = "(?:\\s|&nbsp;|&#0*160;|&#x0*a0;)+"
		return try? NSRegularExpression(pattern: "(?i)" + wordPatterns.joined(separator: separator), options: [])
	}

	static func escapedWordPattern(for word: String) -> String {
		var pattern = ""
		for character in word {
			pattern += entityTolerantPattern(for: character)
		}
		return pattern
	}

	/// Alternation matching a character and its common HTML entity forms.
	static func entityTolerantPattern(for character: Character) -> String {
		switch character {
		case "'", "\u{2018}", "\u{2019}", "`":
			return "(?:'|\u{2018}|\u{2019}|`|&apos;|&lsquo;|&rsquo;|&#0*39;|&#0*96;|&#0*8216;|&#0*8217;|&#x0*27;|&#x0*60;|&#x0*2018;|&#x0*2019;)"
		case "\"", "\u{201C}", "\u{201D}":
			return "(?:\"|\u{201C}|\u{201D}|&quot;|&ldquo;|&rdquo;|&#0*34;|&#0*8220;|&#0*8221;|&#x0*22;|&#x0*201C;|&#x0*201D;)"
		case "&":
			return "(?:&amp;|&#0*38;|&#x0*26;|&)"
		case "-", "\u{2013}", "\u{2014}":
			return "(?:-|\u{2013}|\u{2014}|&ndash;|&mdash;|&#0*45;|&#0*8211;|&#0*8212;|&#x0*2d;|&#x0*2013;|&#x0*2014;)"
		case "\u{00A0}":
			return "(?:\\s|&nbsp;|&#0*160;|&#x0*a0;)+"
		case "\u{2026}":
			return "(?:\u{2026}|&hellip;|&#0*8230;|&#x0*2026;|\\.{3})"
		case "<":
			return "(?:<|&lt;|&#0*60;|&#x0*3c;)"
		case ">":
			return "(?:>|&gt;|&#0*62;|&#x0*3e;)"
		default:
			return NSRegularExpression.escapedPattern(for: String(character))
		}
	}

	/// Matches whole HTML tags, respecting > characters inside single- or
	/// double-quoted attribute values, plus HTML comments.
	static let tagPattern = "(?:<!--[\\s\\S]*?-->|<(?:\"[^\"]*\"|'[^']*'|[^'\">]*)*>)"

	/// Wraps the first occurrence of `needle` found in eligible text segments
	/// between HTML tags. Returns nil when the needle isn't found.
	static func markFirstOccurrence(in html: String, needle: String) -> String? {
		guard let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: []),
			  let regex = needleRegex(for: needle) else {
			return nil
		}

		var markDepth = 0
		var suppressed = false
		let tagMatches = tagRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
		var previousEnd = html.startIndex
		for tagMatch in tagMatches {
			guard let tagRange = Range(tagMatch.range, in: html) else {
				continue
			}
			if markDepth == 0 && !suppressed,
			   let markedSegment = markFirstMatch(in: html[previousEnd..<tagRange.lowerBound], regex: regex) {
				return String(html[..<previousEnd]) + markedSegment + String(html[tagRange.lowerBound...])
			}
			updateState(for: html[tagRange], markDepth: &markDepth, suppressed: &suppressed)
			previousEnd = tagRange.upperBound
		}
		if markDepth == 0 && !suppressed,
		   let markedSegment = markFirstMatch(in: html[previousEnd...], regex: regex) {
			return String(html[..<previousEnd]) + markedSegment
		}
		return nil
	}

	/// Tracks whether following text segments are inside a <mark>,
	/// <script>, or <style> region and therefore ineligible for marking.
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
			suppressed = !isClosingTag(lowered)
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
