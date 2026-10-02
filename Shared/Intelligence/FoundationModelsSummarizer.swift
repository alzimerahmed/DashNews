//
//  FoundationModelsSummarizer.swift
//  DashNews
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
import os
import RSCore

/// Abstractive summarization via Apple's on-device Foundation Models
/// framework (Apple Intelligence). Feature #9. Requires iOS 26 / macOS 26 and
/// a device where the system model reports itself available; callers go
/// through `SummarizationService`, which falls back to
/// `ExtractiveSummarizer` otherwise. Never instantiated when unavailable.
@available(iOS 26.0, macOS 26.0, *)
struct FoundationModelsSummarizer: ArticleSummarizing {

	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "FoundationModelsSummarizer")

	/// Upper bound on article text sent to the model, to stay well inside
	/// the on-device context window.
	static let maximumPromptCharacterCount = 6_000

	static var isAvailable: Bool {
		guard case .available = SystemLanguageModel.default.availability else {
			return false
		}
		return true
	}

	func summarize(title: String?, contentText: String) async -> String? {
		guard Self.isAvailable, !contentText.isEmpty else {
			return nil
		}

		var prompt = "Summarize this news article in two or three short sentences. Use the article's language. Do not add commentary."
		if let title, !title.isEmpty {
			prompt += "\n\nTitle: \(title)"
		}
		prompt += "\n\n\(contentText.prefix(Self.maximumPromptCharacterCount))"

		do {
			let session = LanguageModelSession(instructions: "You summarize news articles for a feed reader. Be accurate and concise.")
			let response = try await session.respond(to: prompt)
			let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
			return summary.isEmpty ? nil : summary
		} catch {
			Self.logger.debug("FoundationModelsSummarizer: summarization failed — \(error, privacy: .public)")
			return nil
		}
	}
}

#endif
