//
//  ArticleSummaryView.swift
//  DashNews
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import SwiftUI

/// On-device summary of an article's text. Feature #9. Cross-platform
/// SwiftUI; presented as a sheet from the iOS article toolbar and as a sheet
/// window from the Mac timeline contextual menu.
@MainActor struct ArticleSummaryView: View {

	let title: String?
	let contentText: String

	private enum SummaryStatus {
		case loading
		case summary(String)
		case unavailable
	}

	@State private var status = SummaryStatus.loading
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			Group {
				switch status {
				case .loading:
					VStack(spacing: 12) {
						ProgressView()
						Text("Summarizing…")
							.foregroundStyle(.secondary)
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				case .summary(let summary):
					ScrollView {
						Text(summary)
							.textSelection(.enabled)
							.padding()
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				case .unavailable:
					ContentUnavailableView(
						"No Summary Available",
						systemImage: "text.badge.xmark",
						description: Text("This article is too short to summarize, or summarization isn't available on this device.")
					)
				}
			}
			.navigationTitle(Text("Summary"))
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") {
						dismiss()
					}
				}
			}
		}
		.formStyle(.grouped)
		.task {
			let result = await SummarizationService.summarize(title: title, contentText: contentText)
			if let result {
				status = .summary(result)
			} else {
				status = .unavailable
			}
		}
	}
}
