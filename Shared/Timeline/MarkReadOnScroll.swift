//
//  MarkReadOnScroll.swift
//  DashNews
//
//  Created by DashNews on 2/13/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import Articles

/// Behavior for the "Mark Read on Scroll" timeline setting: decides which
/// articles should be marked read as they scroll past in the timeline.
enum MarkReadOnScroll {

	/// Returns the subset of `articles` that should be marked read now —
	/// articles that are still unread and have not been handled during this
	/// scroll session. Handled article IDs are added to `handledArticleIDs`,
	/// so each article is marked at most once per session.
	static func articlesToMark(in articles: [Article], handledArticleIDs: inout Set<String>) -> [Article] {
		var unreadArticles = [Article]()
		for article in articles where !article.status.read {
			if handledArticleIDs.insert(article.articleID).inserted {
				unreadArticles.append(article)
			}
		}
		return unreadArticles
	}
}
