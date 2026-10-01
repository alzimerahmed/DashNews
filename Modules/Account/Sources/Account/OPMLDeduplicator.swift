//
//  OPMLDeduplicator.swift
//  Account
//
//  Created by DashNews on 2/13/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation
import RSParser

/// Removes duplicate feeds from an OPML document before import, matching by
/// feed URL. Exact duplicates — both feeds already in the account and repeats
/// within the file itself, across folder boundaries — are skipped and counted.
enum OPMLDeduplicator {

	static func deduplicate(_ items: [OPMLItem], existingFeedURLs: Set<String>) -> (items: [OPMLItem], duplicatesSkipped: Int) {
		var duplicatesSkipped = 0
		var seenFeedURLs = Set<String>()
		let items = deduplicate(items, existingFeedURLs: existingFeedURLs, seenFeedURLs: &seenFeedURLs, duplicatesSkipped: &duplicatesSkipped)
		return (items, duplicatesSkipped)
	}

	private static func deduplicate(_ items: [OPMLItem], existingFeedURLs: Set<String>, seenFeedURLs: inout Set<String>, duplicatesSkipped: inout Int) -> [OPMLItem] {
		var deduplicatedItems = [OPMLItem]()

		for item in items {
			if item.feedSpecifier != nil {
				guard let feedURL = item.feedSpecifier?.feedURL else {
					// Not a usable feed reference — keep it and let the
					// import layer decide, rather than silently dropping it.
					deduplicatedItems.append(item)
					continue
				}
				if existingFeedURLs.contains(feedURL) {
					duplicatesSkipped += 1
					continue
				}
				if !seenFeedURLs.insert(feedURL).inserted {
					duplicatesSkipped += 1
					continue
				}
				deduplicatedItems.append(item)
				continue
			}

			if let children = item.children {
				let folder = OPMLItem(attributes: item.attributes)
				for child in deduplicate(children, existingFeedURLs: existingFeedURLs, seenFeedURLs: &seenFeedURLs, duplicatesSkipped: &duplicatesSkipped) {
					folder.addChild(child)
				}
				deduplicatedItems.append(folder)
				continue
			}
			deduplicatedItems.append(item)
		}

		return deduplicatedItems
	}
}
