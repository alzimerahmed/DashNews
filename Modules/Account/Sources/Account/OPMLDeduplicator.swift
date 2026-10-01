//
//  OPMLDeduplicator.swift
//  Account
//
//  Created by DashNews on 2/13/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation
import RSParser

/// Result of deduplicating an OPML document before import.
public struct OPMLDeduplicationResult {

	public let items: [OPMLItem]
	public let duplicatesSkipped: Int
}

/// Removes duplicate feeds from an OPML document before import, matching by
/// feed URL. Exact duplicates — both feeds already in the account and repeats
/// within the file itself — are skipped and counted.
enum OPMLDeduplicator {

	static func deduplicate(_ items: [OPMLItem], existingFeedURLs: Set<String>) -> (items: [OPMLItem], duplicatesSkipped: Int) {
		var duplicatesSkipped = 0
		let items = deduplicate(items, existingFeedURLs: existingFeedURLs, duplicatesSkipped: &duplicatesSkipped)
		return (items, duplicatesSkipped)
	}

	private static func deduplicate(_ items: [OPMLItem], existingFeedURLs: Set<String>, duplicatesSkipped: inout Int) -> [OPMLItem] {
		var seenFeedURLs = Set<String>()
		var deduplicatedItems = [OPMLItem]()

		for item in items {
			if item.feedSpecifier != nil {
				guard let feedURL = item.feedSpecifier?.feedURL else {
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
				for child in deduplicate(children, existingFeedURLs: existingFeedURLs, duplicatesSkipped: &duplicatesSkipped) {
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
