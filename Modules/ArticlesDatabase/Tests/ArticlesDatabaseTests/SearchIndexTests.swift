//
//  SearchIndexTests.swift
//  ArticlesDatabase
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import Testing
import Articles
import RSParser
import ArticlesDatabase

/// The search index is an FTS5 virtual table over article title/body, keyed by
/// the articles.searchRowID column. These tests pin indexing, querying, and
/// full-rebuild behavior.
@MainActor @Suite final class SearchIndexTests {

	private let database: ArticlesDatabase
	private let feedID = "feed1"

	init() {
		self.database = ArticlesDatabase(databaseFilePath: ":memory:", accountID: "test", retentionStyle: .feedBased)
	}

	@Test func searchFindsArticleByTitleWord() async {
		await seedArticle(uniqueID: "s1", title: "Quantum Computing Advances", contentHTML: "<p>Unrelated body text.</p>")
		let articles = await database.fetchArticlesMatchingAsync(searchString: "quantum", feedIDs: [feedID])
		#expect(articles.count == 1)
	}

	@Test func searchFindsArticleByBodyWord() async {
		await seedArticle(uniqueID: "s2", title: "Daily Report", contentHTML: "<p>The mesoglea is remarkably thick today.</p>")
		let articles = await database.fetchArticlesMatchingAsync(searchString: "mesoglea", feedIDs: [feedID])
		#expect(articles.count == 1)
	}

	@Test func searchFindsNothingForUnknownWord() async {
		await seedArticle(uniqueID: "s3", title: "Known Title", contentHTML: "<p>Known body.</p>")
		let articles = await database.fetchArticlesMatchingAsync(searchString: "xyzzyq", feedIDs: [feedID])
		#expect(articles.isEmpty)
	}

	@Test func searchDoesNotMatchOtherFeeds() async {
		await seedArticle(uniqueID: "s4", title: "Ferrous Wheel", contentHTML: "<p>Body.</p>")
		let articles = await database.fetchArticlesMatchingAsync(searchString: "ferrous", feedIDs: ["otherFeed"])
		#expect(articles.isEmpty)
	}

	@Test func searchIndexUpdatesWhenArticleContentChanges() async {
		let articles = await seedArticle(uniqueID: "s5", title: "Update Me", contentHTML: "<p>Original zephyr text.</p>")
		#expect(await database.fetchArticlesMatchingAsync(searchString: "zephyr", feedIDs: [feedID]).count == 1)

		guard let article = articles.first else {
			Issue.record("Expected a seeded article")
			return
		}
		let updatedItem = ParsedItem(syncServiceID: nil, uniqueID: article.uniqueID, feedURL: feedID, url: article.url, externalURL: nil, title: "Update Me", language: nil, contentHTML: "<p>Replaced verdigris text.</p>", contentText: nil, markdown: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: article.datePublished, dateModified: Date(), authors: nil, tags: nil, attachments: nil)
		_ = await database.updateAsync(parsedItems: [updatedItem], feedID: feedID, deleteOlder: false)

		#expect(await database.fetchArticlesMatchingAsync(searchString: "verdigris", feedIDs: [feedID]).count == 1)
		#expect(await database.fetchArticlesMatchingAsync(searchString: "zephyr", feedIDs: [feedID]).isEmpty)
	}

	@Test func rebuildIndexRestoresSearchResults() async {
		await seedArticle(uniqueID: "s6", title: "Rebuild Target", contentHTML: "<p>Cormorant nesting habits.</p>")
		#expect(await database.fetchArticlesMatchingAsync(searchString: "cormorant", feedIDs: [feedID]).count == 1)

		await database.rebuildSearchIndexAsync()

		#expect(await database.fetchArticlesMatchingAsync(searchString: "cormorant", feedIDs: [feedID]).count == 1)
		#expect(await database.fetchArticlesMatchingAsync(searchString: "rebuild", feedIDs: [feedID]).count == 1)
		#expect(await database.fetchArticlesMatchingAsync(searchString: "nosuchword", feedIDs: [feedID]).isEmpty)
	}
}

// MARK: - Helpers

private extension SearchIndexTests {

	func seedArticle(uniqueID: String, title: String, contentHTML: String) async -> Set<Article> {
		let item = ParsedItem(syncServiceID: nil, uniqueID: uniqueID, feedURL: feedID, url: "https://example.com/\(uniqueID)", externalURL: nil, title: title, language: nil, contentHTML: contentHTML, contentText: nil, markdown: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: Date(), dateModified: nil, authors: nil, tags: nil, attachments: nil)
		let changes = await database.updateAsync(parsedItems: [item], feedID: feedID, deleteOlder: false)
		#expect((changes.new ?? Set<Article>()).count == 1)
		return changes.new ?? Set<Article>()
	}
}
