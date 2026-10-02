//
//  KeywordRule.swift
//  DashNews
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation

/// What to do when an article matches a keyword rule.
enum KeywordRuleAction: String, Codable, CaseIterable, Sendable {
	case hide
	case highlight
}

/// A per-feed keyword rule evaluated on-device. Feature #2 — local mute/filter rules.
/// Hide rules remove matching articles from the timeline; highlight rules mark
/// matching text in the rendered article.
struct KeywordRule: Codable, Hashable, Sendable, Identifiable {

	let id: UUID
	let feedID: String
	var keyword: String
	var action: KeywordRuleAction

	init(id: UUID = UUID(), feedID: String, keyword: String, action: KeywordRuleAction) {
		self.id = id
		self.feedID = feedID
		self.keyword = keyword
		self.action = action
	}
}
