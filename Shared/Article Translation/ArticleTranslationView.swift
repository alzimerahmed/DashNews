//
//  ArticleTranslationView.swift
//  DashNews
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import SwiftUI

#if canImport(Translation)
import Translation

/// System translation of an article's text using the Translation framework.
/// Feature #11. Available on iOS 17.4+ / macOS 14.4+; call sites must gate
/// with `#available(iOS 17.4, macOS 14.4, *)` so older OS builds still compile.
@available(iOS 17.4, macOS 14.4, *)
@MainActor struct ArticleTranslationView: View {

	let sourceText: String

	@State private var configuration: TranslationSession.Configuration?
	@State private var translatedText: String?
	@State private var translationFailed = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				if let translatedText {
					Text(translatedText)
						.textSelection(.enabled)
					Divider()
					Text(sourceText)
						.font(.callout)
						.foregroundStyle(.secondary)
						.textSelection(.enabled)
				} else {
					Text(sourceText)
						.textSelection(.enabled)
				}
			}
			.padding()
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.navigationTitle(Text("Translate"))
		.toolbar {
			ToolbarItem {
				Button {
					// Re-open the language picker.
					configuration?.invalidate()
					configuration = TranslationSession.Configuration()
				} label: {
					Label("Language", systemImage: "globe")
				}
			}
		}
		.translationTask(configuration) { session in
			do {
				let response = try await session.translate(sourceText)
				translatedText = response.targetText
			} catch {
				translationFailed = true
			}
		}
		.onAppear {
			if configuration == nil {
				configuration = TranslationSession.Configuration()
			}
		}
		.overlay {
			if translationFailed {
				ContentUnavailableView("Translation Unavailable", systemImage: "globe", description: Text("The article could not be translated."))
			}
		}
	}
}

#endif
