//
//  SmartFeedsController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account

@MainActor final class SmartFeedsController: DisplayNameProvider, ContainerIdentifiable {
	nonisolated let containerID: ContainerIdentifier? = ContainerIdentifier.smartFeedController

	public static let shared = SmartFeedsController()
	let nameForDisplay = NSLocalizedString("Smart Feeds", comment: "Smart Feeds group title")

	let todayFeed = SmartFeed(delegate: TodayFeedDelegate())
	let unreadFeed = UnreadFeed()
	let starredFeed = SmartFeed(delegate: StarredFeedDelegate())
	private let savedSearchesStore = SavedSearchStore()
	private var savedSearchFeeds = [SmartFeed]()

	var smartFeeds = [SidebarItem]()

	private init() {
		rebuildSavedSearchFeeds()
	}

	func find(by identifier: SidebarItemIdentifier) -> PseudoFeed? {
		switch identifier {
		case .smartFeed(let stringIdentifer):
			switch stringIdentifer {
			case String(describing: TodayFeedDelegate.self):
				return todayFeed
			case String(describing: UnreadFeed.self):
				return unreadFeed
			case String(describing: StarredFeedDelegate.self):
				return starredFeed
			default:
				return savedSearchFeed(matching: identifier)
			}
		default:
			return nil
		}
	}

	// MARK: - Saved Searches

	/// Saves a search string as a persistent smart feed. Returns the existing
	/// saved search if this exact search string was saved before.
	@discardableResult
	func addSavedSearch(name: String, searchString: String) -> SavedSearch? {
		let trimmedName = name.trimmingWhitespace
		let trimmedSearchString = searchString.trimmingWhitespace
		guard !trimmedSearchString.isEmpty else {
			return nil
		}
		guard let savedSearch = savedSearchesStore.add(name: trimmedName, searchString: trimmedSearchString) else {
			return nil
		}
		let sidebarItemID = SavedSearchFeedDelegate.sidebarItemID(for: savedSearch.id)
		let didAdd = !savedSearchFeeds.contains { $0.sidebarItemID == sidebarItemID }
		rebuildSavedSearchFeeds()
		if didAdd {
			postChildrenDidChange()
		}
		return savedSearch
	}

	func renameSavedSearch(id: UUID, to name: String) {
		savedSearchesStore.rename(id: id, to: name)
		rebuildSavedSearchFeeds()
		// The Mac sidebar ignores DisplayNameDidChange with a nil object, and the
		// rebuilt feeds are new objects — post ChildrenDidChange so the tree rebuilds.
		postChildrenDidChange()
		if let feed = savedSearchFeed(id: id) {
			NotificationCenter.default.post(name: .DisplayNameDidChange, object: feed)
		}
	}

	func deleteSavedSearch(id: UUID) {
		savedSearchesStore.remove(id: id)
		rebuildSavedSearchFeeds()
		postChildrenDidChange()
	}

	func savedSearchFeed(id: UUID) -> SmartFeed? {
		let sidebarItemID = SavedSearchFeedDelegate.sidebarItemID(for: id)
		return savedSearchFeeds.first { $0.sidebarItemID == sidebarItemID }
	}
}

// MARK: - Private

private extension SmartFeedsController {

	func savedSearchFeed(matching identifier: SidebarItemIdentifier) -> PseudoFeed? {
		guard case .smartFeed(let stringIdentifier) = identifier, stringIdentifier.hasPrefix(SavedSearchFeedDelegate.sidebarItemIDPrefix) else {
			return nil
		}
		return savedSearchFeeds.first { $0.sidebarItemID == identifier }
	}

	func rebuildSavedSearchFeeds() {
		savedSearchFeeds = savedSearchesStore.savedSearches.map { SmartFeed(delegate: SavedSearchFeedDelegate(savedSearch: $0)) }
		smartFeeds = [todayFeed, unreadFeed, starredFeed] + savedSearchFeeds
	}

	func postChildrenDidChange() {
		NotificationCenter.default.post(name: .ChildrenDidChange, object: nil)
	}
}
