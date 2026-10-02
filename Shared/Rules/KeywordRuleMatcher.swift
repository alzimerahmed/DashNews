//
//  KeywordRuleMatcher.swift
//  DashNews
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import Articles

/// Pure rule-matching logic for keyword rules. Feature #2.
/// Matching is case-insensitive and substring-based, evaluated against the
/// article title, summary, and extracted plain text.
nonisolated enum KeywordRuleMatcher {

	/// Returns true if any hide rule matches the article.
	static func shouldHide(article: Article, rules: [KeywordRule]) -> Bool {
		let hideKeywords = rules.filter { $0.action == .hide }.map { $0.keyword }
		guard !hideKeywords.isEmpty else {
			return false
		}
		return hideKeywords.contains { keyword in
			matches(keyword: keyword, in: searchableText(of: article))
		}
	}

	/// Case-insensitive substring match.
	static func matches(keyword: String, in text: String) -> Bool {
		let trimmedKeyword = keyword.trimmingWhitespace
		guard !trimmedKeyword.isEmpty else {
			return false
		}
		return text.range(of: trimmedKeyword, options: .caseInsensitive) != nil
	}

	/// The plain text a rule is evaluated against.
	static func searchableText(of article: Article) -> String {
		var parts = [String]()
		if let title = article.title {
			parts.append(title)
		}
		if let summary = article.summary {
			parts.append(summary)
		}
		if let contentText = article.contentText {
			parts.append(contentText)
		}
		return parts.joined(separator: "\n")
	}
}
