//
//  KeywordRulesView.swift
//  DashNews
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import SwiftUI
import Account
import Articles

/// Editor for a feed's keyword hide/highlight rules. Feature #2.
/// Cross-platform SwiftUI; presented from the feed inspector/context menus
/// on both platforms.
@MainActor struct KeywordRulesView: View {

	let feed: Feed

	@ObservedObject private var store = KeywordRuleStore.shared
	@State private var newKeyword = ""
	@State private var newAction: KeywordRuleAction = .hide
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			List {
				Section {
					ForEach(store.rules(forFeedID: feed.feedID)) { rule in
						HStack {
							Image(systemName: rule.action == .hide ? "eye.slash" : "highlighter")
								.foregroundStyle(rule.action == .hide ? Color.red : Color.orange)
								.accessibilityHidden(true) // The action name is already read as text.
							Text(rule.keyword)
							Spacer()
							Text(actionLabel(rule.action))
								.font(.caption)
								.foregroundStyle(.secondary)
						}
						.deleteDisabled(false)
					}
					.onDelete { indexSet in
						let feedRules = store.rules(forFeedID: feed.feedID)
						let idsToRemove = indexSet.compactMap { index in
							feedRules.indices.contains(index) ? feedRules[index].id : nil
						}
						for id in idsToRemove {
							store.remove(id: id)
						}
					}
					if store.rules(forFeedID: feed.feedID).isEmpty {
						Text("No rules for this feed. Articles matching a hide rule are removed from the timeline; matches in a highlight rule are marked in the article text.")
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
				} header: {
					Text("Rules")
				}

				Section {
					TextField("Keyword", text: $newKeyword)
					Picker("Action", selection: $newAction) {
						ForEach(KeywordRuleAction.allCases, id: \.self) { action in
							Text(actionLabel(action)).tag(action)
						}
					}
					Button("Add Rule") {
						store.add(feedID: feed.feedID, keyword: newKeyword, action: newAction)
						newKeyword = ""
					}
					.disabled(newKeyword.trimmingWhitespace.isEmpty)
				} header: {
					Text("Add Rule")
				}
			}
			.navigationTitle(feed.nameForDisplay)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") {
						dismiss()
					}
				}
			}
		}
		.formStyle(.grouped)
	}
}

// MARK: - Private

private extension KeywordRulesView {

	func actionLabel(_ action: KeywordRuleAction) -> LocalizedStringKey {
		switch action {
		case .hide:
			return "Hide"
		case .highlight:
			return "Highlight"
		}
	}
}
