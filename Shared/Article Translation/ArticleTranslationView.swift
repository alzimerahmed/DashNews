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

/// System translation of an article's text using the Translation framework's
/// presentation API. Feature #11. TranslationSession/translationPresentation
/// are available on iOS 18+ / macOS 15+; call sites must gate with
/// `#available(iOS 18.0, macOS 15.0, *)` so older OS builds still compile.
@available(iOS 18.0, macOS 15.0, *)
@MainActor struct ArticleTranslationView: View {

	let sourceText: String

	@State private var isTranslationPresented = false

	var body: some View {
		ScrollView {
			Text(sourceText)
				.textSelection(.enabled)
				.padding()
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.navigationTitle(Text("Translate"))
		.toolbar {
			ToolbarItem {
				Button(String("Translate")) {
					isTranslationPresented = true
				}
			}
		}
		.translationPresentation(isPresented: $isTranslationPresented, text: sourceText)
	}
}

#endif
