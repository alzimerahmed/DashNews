//
//  OPMLDeduplicatorTests.swift
//  AccountTests
//
//  Created by DashNews on 2/13/26.
//

import Testing
import RSParser
@testable import Account

@MainActor struct OPMLDeduplicatorTests {

	@Test func exactDuplicateFeedsInTheFileAreSkipped() throws {
		let items = try opmlItems("""
		<outline text="Feed One" title="Feed One" type="rss" version="RSS" htmlUrl="https://example.com/" xmlUrl="https://example.com/feed.xml"/>
		<outline text="Feed One Copy" title="Feed One Copy" type="rss" version="RSS" htmlUrl="https://example.com/" xmlUrl="https://example.com/feed.xml"/>
		""")

		let result = OPMLDeduplicator.deduplicate(items, existingFeedURLs: [])

		#expect(result.items.count == 1)
		#expect(result.duplicatesSkipped == 1)
	}

	@Test func feedsAlreadyInTheAccountAreSkipped() throws {
		let items = try opmlItems("""
		<outline text="Existing Feed" title="Existing Feed" type="rss" version="RSS" htmlUrl="https://example.com/" xmlUrl="https://example.com/already-subscribed.xml"/>
		<outline text="New Feed" title="New Feed" type="rss" version="RSS" htmlUrl="https://example.org/" xmlUrl="https://example.org/new.xml"/>
		""")

		let result = OPMLDeduplicator.deduplicate(items, existingFeedURLs: ["https://example.com/already-subscribed.xml"])

		#expect(result.items.count == 1)
		#expect(result.items.first?.feedSpecifier?.feedURL == "https://example.org/new.xml")
		#expect(result.duplicatesSkipped == 1)
	}

	@Test func foldersAreKeptAndDeduplicatedInside() throws {
		let items = try opmlItems("""
		<outline text="News" title="News">
			<outline text="Feed One" title="Feed One" type="rss" version="RSS" htmlUrl="https://example.com/" xmlUrl="https://example.com/feed.xml"/>
			<outline text="Feed One Copy" title="Feed One Copy" type="rss" version="RSS" htmlUrl="https://example.com/" xmlUrl="https://example.com/feed.xml"/>
		</outline>
		""")

		let result = OPMLDeduplicator.deduplicate(items, existingFeedURLs: [])

		#expect(result.items.count == 1)
		#expect(result.items.first?.children?.count == 1)
		#expect(result.duplicatesSkipped == 1)
	}

	@Test func distinctFeedsAreAllKept() throws {
		let items = try opmlItems("""
		<outline text="Feed One" title="Feed One" type="rss" version="RSS" htmlUrl="https://example.com/" xmlUrl="https://example.com/one.xml"/>
		<outline text="Feed Two" title="Feed Two" type="rss" version="RSS" htmlUrl="https://example.org/" xmlUrl="https://example.org/two.xml"/>
		""")

		let result = OPMLDeduplicator.deduplicate(items, existingFeedURLs: [])

		#expect(result.items.count == 2)
		#expect(result.duplicatesSkipped == 0)
	}

	@Test func manualImportSkipsFeedsTheAccountAlreadyHas() throws {
		let account = accountManager.createAccount(type: .onMyMac)
		defer {
			accountManager.deleteAccount(account)
		}

		account.loadOPMLItems(try singleFeedOPMLItems(), isManualImport: true)
		#expect(account.flattenedFeeds().count == 1)

		// Importing the same feed again must not create a duplicate.
		account.loadOPMLItems(try singleFeedOPMLItems(), isManualImport: true)

		#expect(account.flattenedFeeds().count == 1)
		#expect(account.lastOPMLImportDuplicatesSkipped == 1)
	}

	@Test func duplicatesAcrossFoldersAreSkipped() throws {
		let items = try opmlItems("""
		<outline text="Folder A" title="Folder A">
			<outline text="Feed One" title="Feed One" type="rss" version="RSS" htmlUrl="https://example.com/" xmlUrl="https://example.com/feed.xml"/>
		</outline>
		<outline text="Folder B" title="Folder B">
			<outline text="Feed One Again" title="Feed One Again" type="rss" version="RSS" htmlUrl="https://example.com/" xmlUrl="https://example.com/feed.xml"/>
		</outline>
		""")

		let result = OPMLDeduplicator.deduplicate(items, existingFeedURLs: [])

		#expect(result.items.count == 2)
		#expect(result.items.first?.children?.count == 1)
		#expect(result.items.last?.children?.isEmpty == true)
		#expect(result.duplicatesSkipped == 1)
	}

	@Test func outlinesWithoutAFeedURLAreKept() throws {
		let items = try opmlItems("""
		<outline text="Just a folder" title="Just a folder"/>
		<outline text="Feed One" title="Feed One" type="rss" version="RSS" htmlUrl="https://example.com/" xmlUrl="https://example.com/feed.xml"/>
		""")

		let result = OPMLDeduplicator.deduplicate(items, existingFeedURLs: [])

		#expect(result.items.count == 2)
		#expect(result.duplicatesSkipped == 0)
	}

	// MARK: - Helpers

	private let accountManager = TestAccountManager()

	private func singleFeedOPMLItems() throws -> [OPMLItem] {
		try opmlItems("<outline text=\"Feed One\" title=\"Feed One\" type=\"rss\" version=\"RSS\" htmlUrl=\"https://example.com/\" xmlUrl=\"https://example.com/feed.xml\"/>")
	}
	private func opmlItems(_ outlines: String) throws -> [OPMLItem] {
		let opml = """
		<?xml version="1.0" encoding="UTF-8"?>
		<opml version="1.1">
		<body>
		\(outlines)
		</body>
		</opml>
		"""
		let data = try #require(opml.data(using: .utf8))
		let parserData = ParserData(url: "https://example.com/subscriptions.opml", data: data)
		let document = try OPMLParser.parseOPML(with: parserData)

		return try #require(document.children)
	}
}
