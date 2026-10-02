//
//  ArticleSummarizing.swift
//  DashNews
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation

/// Generates a short summary of an article's text. Feature #9 — on-device
/// summarization. Implementations run entirely on-device and return nil when
/// a summary can't be produced (content too short, model unavailable).
protocol ArticleSummarizing: Sendable {

	/// Returns a summary of `contentText`, or nil when summarization isn't possible.
	func summarize(title: String?, contentText: String) async -> String?
}
