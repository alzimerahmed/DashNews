//
//  SearchMigrationTests.swift
//  ArticlesDatabase
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import Testing
import Articles
import RSParser
import SQLite3
import ArticlesDatabase

/// Databases created before the FTS5 migration have an FTS4 virtual table named
/// `search`. Opening such a database must drop the legacy index, create the FTS5
/// virtual table, and reindex all articles. These tests build a legacy fixture
/// database on disk and verify the migration end-to-end.
@MainActor @Suite final class SearchMigrationTests {

	private let feedID = "feed1"

	@Test func legacyFTS4DatabaseIsMigratedAndReindexed() async {
		let databasePath = Self.makeTemporaryDatabasePath()
		Self.createLegacyDatabase(at: databasePath)

		let database = ArticlesDatabase(databaseFilePath: databasePath, accountID: "test", retentionStyle: .feedBased)
		defer {
			try? FileManager.default.removeItem(atPath: databasePath)
		}

		// The legacy search row indexed the title "Legacy Title" and the body
		// "legacy body text". After the migration the index is rebuilt from the
		// articles table, so both words must match again.
		let articles = await Self.waitForSearchResults("legacy", database: database, feedIDs: [feedID])
		#expect(articles.count == 1)

		// A phrase query over the rebuilt index succeeds.
		let phraseResults = await database.fetchArticlesMatchingAsync(searchString: "legacy body", feedIDs: [feedID])
		#expect(phraseResults.count == 1)

		// Article data and statuses survived the migration.
		let fetchedArticles = await database.fetchArticlesAsync(feedID: feedID)
		#expect(fetchedArticles.count == 1)
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 1)

		// New articles are indexed into the FTS5 table.
		let item = ParsedItem(syncServiceID: nil, uniqueID: "post-migration", feedURL: feedID, url: "https://example.com/post-migration", externalURL: nil, title: "Freshly Written", language: nil, contentHTML: "<p>Brand new quokka content.</p>", contentText: nil, markdown: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: Date(), dateModified: nil, authors: nil, tags: nil, attachments: nil)
		_ = await database.updateAsync(parsedItems: [item], feedID: feedID, deleteOlder: false)
		#expect(await database.fetchArticlesMatchingAsync(searchString: "quokka", feedIDs: [feedID]).count == 1)
	}

	@Test func freshDatabaseSearchWorks() async {
		let database = ArticlesDatabase(databaseFilePath: ":memory:", accountID: "test", retentionStyle: .feedBased)
		let item = ParsedItem(syncServiceID: nil, uniqueID: "f1", feedURL: feedID, url: "https://example.com/f1", externalURL: nil, title: "Solar Sailing", language: nil, contentHTML: "<p>Photon pressure propulsion.</p>", contentText: nil, markdown: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: Date(), dateModified: nil, authors: nil, tags: nil, attachments: nil)
		_ = await database.updateAsync(parsedItems: [item], feedID: feedID, deleteOlder: false)

		#expect(await database.fetchArticlesMatchingAsync(searchString: "photon", feedIDs: [feedID]).count == 1)
		#expect(await database.fetchArticlesMatchingAsync(searchString: "solar", feedIDs: [feedID]).count == 1)
	}
}

// MARK: - Helpers

private extension SearchMigrationTests {

	static func makeTemporaryDatabasePath() -> String {
		NSTemporaryDirectory().appendingPathComponent("legacy-search-\(UUID().uuidString).db")
	}

	/// Creates a database with the pre-FTS5 schema: articles without the
	/// markdown/authors columns, statuses, and an FTS4 `search` virtual table
	/// with one indexed row linked via articles.searchRowID.
	static func createLegacyDatabase(at path: String) {
		var database: OpaquePointer?
		let openResult = sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
		guard openResult == SQLITE_OK, let database else {
			sqlite3_close_v2(database)
			Issue.record("Could not open legacy fixture database at \(path)")
			return
		}
		defer {
			sqlite3_close_v2(database)
		}

		let statements = """
		CREATE TABLE if not EXISTS articles (articleID TEXT NOT NULL PRIMARY KEY, feedID TEXT NOT NULL, uniqueID TEXT NOT NULL, title TEXT, contentHTML TEXT, contentText TEXT, url TEXT, externalURL TEXT, summary TEXT, imageURL TEXT, bannerImageURL TEXT, datePublished DATE, dateModified DATE, searchRowID INTEGER);
		CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0);
		CREATE VIRTUAL TABLE if not EXISTS search using fts4(title, body);
		CREATE TRIGGER if not EXISTS articles_after_delete_trigger_delete_search_text after delete on articles begin delete from search where rowid = OLD.searchRowID; end;
		INSERT INTO articles (articleID, feedID, uniqueID, title, contentHTML, datePublished, searchRowID) VALUES ('legacy-1', 'feed1', 'legacy-1', 'Legacy Title', '<p>Legacy body text.</p>', 0, 1);
		INSERT INTO statuses (articleID, read, starred, dateArrived) VALUES ('legacy-1', 0, 0, 0);
		INSERT INTO search (rowid, title, body) VALUES (1, 'legacy title', 'legacy body text');
		"""
		guard executeStatements(statements, database: database) else {
			Issue.record("Could not create legacy fixture database at \(path)")
			return
		}
	}

	/// Executes a batch of semicolon-separated SQL statements, stopping at the
	/// first error. Returns false if any statement failed.
	private static func executeStatements(_ statements: String, database: OpaquePointer) -> Bool {
		var errorMessage: UnsafeMutablePointer<CChar>?
		defer {
			sqlite3_free(errorMessage)
		}
		return sqlite3_exec(database, statements, nil, nil, &errorMessage) == SQLITE_OK
	}

	/// Indexing after the migration happens in batches on the DatabaseQueue serial queue;
	/// poll until the reindex completes or the timeout elapses.
	static func waitForSearchResults(_ searchString: String, database: ArticlesDatabase, feedIDs: Set<String>) async -> Set<Article> {
		for _ in 0..<200 {
			let articles = await database.fetchArticlesMatchingAsync(searchString: searchString, feedIDs: feedIDs)
			if !articles.isEmpty {
				return articles
			}
			try? await Task.sleep(nanoseconds: 10_000_000)
		}
		return await database.fetchArticlesMatchingAsync(searchString: searchString, feedIDs: feedIDs)
	}
}
