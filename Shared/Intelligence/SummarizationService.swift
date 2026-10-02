//
//  SummarizationService.swift
//  DashNews
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import Articles
import RSCore

/// Front door for on-device article summarization. Feature #9.
///
/// Uses Apple Foundation Models when the system model is available
/// (iOS 26 / macOS 26 on Apple Intelligence devices); otherwise falls back
/// to the deterministic `ExtractiveSummarizer`. Returns nil when the article
/// is too short to summarize or no summarizer can produce output, so callers
/// show an empty state rather than an error.
nonisolated enum SummarizationService {

	/// @concurrent so the pure-CPU extractive path runs off the caller's
	/// actor (NonisolatedNonsendingByDefault would otherwise keep it on the
	/// main actor when called from the view's .task).
	@concurrent
	static func summarize(title: String?, contentText: String) async -> String? {
		let trimmed = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			return nil
		}

		#if canImport(FoundationModels)
		if #available(iOS 26.0, macOS 26.0, *), FoundationModelsSummarizer.isAvailable {
			if let summary = await FoundationModelsSummarizer().summarize(title: title, contentText: trimmed) {
				return summary
			}
		}
		#endif

		return await ExtractiveSummarizer().summarize(title: title, contentText: trimmed)
	}
}

extension Article {

	/// The plain text used for summarization and key-sentence scoring: the
	/// parser-provided contentText when present, else the rendered body with
	/// HTML stripped.
	var summarizableText: String {
		if let contentText, !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return contentText
		}
		return body?.strippingHTML() ?? ""
	}
}
