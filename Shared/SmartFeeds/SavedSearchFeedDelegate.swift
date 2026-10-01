//
//  SavedSearchFeedDelegate.swift
//  NetNewsWire
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import RSCore
import Account
import Articles
import ArticlesDatabase
import Images

/// Smart feed delegate for a user-saved search. Behaves like a global search
/// smart feed, but persists across launches via SavedSearchStore.
struct SavedSearchFeedDelegate: SmartFeedDelegate {

	var sidebarItemID: SidebarItemIdentifier? {
		guard let savedSearchID else {
			return nil
		}
		return SidebarItemIdentifier.smartFeed(Self.sidebarItemIDPrefix + savedSearchID.uuidString)
	}

	var nameForDisplay: String {
		savedSearch.name
	}

	let savedSearch: SavedSearch
	let searchString: String
	let fetchType: FetchType
	let smallIcon: IconImage? = Assets.Images.searchFeed

	init(savedSearch: SavedSearch) {
		self.savedSearch = savedSearch
		self.searchString = savedSearch.searchString
		self.fetchType = .search(savedSearch.searchString)
	}

	var savedSearchID: UUID? {
		savedSearch.id
	}

	static func sidebarItemID(for id: UUID) -> SidebarItemIdentifier {
		SidebarItemIdentifier.smartFeed(sidebarItemIDPrefix + id.uuidString)
	}

	static let sidebarItemIDPrefix = "savedSearch-"

	func fetchUnreadCount(account: Account) async -> Int {
		// Saved searches are search-result feeds; unread counts are not tracked. // TODO: after 5.0
		0
	}
}
