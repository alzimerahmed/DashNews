//
//  KeywordRuleStore.swift
//  DashNews
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import os
import RSCore

/// Loads and saves per-feed keyword rules from a JSON file.
/// Feature #2 — local mute/filter rules. The file URL is injectable so
/// persistence logic can be unit tested. All access is main-thread only,
/// matching the rest of the app-layer state.
@MainActor final class KeywordRuleStore: ObservableObject {

	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "KeywordRuleStore")

	@Published private(set) var rules: [KeywordRule]

	private let fileURL: URL

	static func defaultFileURL() -> URL {
		AppConfig.dataFolder.appendingPathComponent("KeywordRules.json")
	}

	static let shared = KeywordRuleStore()

	init(fileURL: URL = KeywordRuleStore.defaultFileURL()) {
		self.fileURL = fileURL
		self.rules = KeywordRuleStore.loadRules(from: fileURL)
	}

	/// Adds a rule. Does nothing if the same feed/keyword/action combination already exists.
	/// Returns nil if the keyword is empty or whitespace-only.
	/// Returns the rule, whether newly created or pre-existing.
	@discardableResult
	func add(feedID: String, keyword: String, action: KeywordRuleAction) -> KeywordRule? {
		let trimmedKeyword = keyword.trimmingWhitespace
		guard !trimmedKeyword.isEmpty else {
			return nil
		}
		if let existing = rules.first(where: { $0.feedID == feedID && $0.keyword == trimmedKeyword && $0.action == action }) {
			return existing
		}
		let rule = KeywordRule(feedID: feedID, keyword: trimmedKeyword, action: action)
		rules.append(rule)
		save()
		return rule
	}

	func remove(id: UUID) {
		rules.removeAll { $0.id == id }
		save()
	}

	func rules(forFeedID feedID: String) -> [KeywordRule] {
		rules.filter { $0.feedID == feedID }
	}

	func hideRules(forFeedID feedID: String) -> [KeywordRule] {
		rules(forFeedID: feedID).filter { $0.action == .hide }
	}

	func highlightKeywords(forFeedID feedID: String) -> [String] {
		rules(forFeedID: feedID).filter { $0.action == .highlight }.map { $0.keyword }
	}
}

// MARK: - Private

private extension KeywordRuleStore {

	static let jsonEncoder = JSONEncoder()

	static func loadRules(from fileURL: URL) -> [KeywordRule] {
		guard let data = try? Data(contentsOf: fileURL) else {
			return []
		}
		do {
			return try JSONDecoder().decode([KeywordRule].self, from: data)
		} catch {
			// A corrupt or unreadable file is recoverable: rules reset
			// to empty rather than crashing the app.
			Self.logger.error("KeywordRuleStore: could not decode \(fileURL.path, privacy: .public) — \(error, privacy: .public)")
			return []
		}
	}

	func save() {
		do {
			let data = try Self.jsonEncoder.encode(rules)
			try data.write(to: fileURL, options: .atomic)
		} catch {
			Self.logger.error("KeywordRuleStore: could not save \(self.fileURL.path, privacy: .public) — \(error, privacy: .public)")
		}
	}
}
