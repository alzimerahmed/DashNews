//
//  MarkReadOnScrollTests.swift
//  NetNewsWireTests
//
//  Created by DashNews on 2/13/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import XCTest
import Articles
@testable import NetNewsWire

@MainActor final class MarkReadOnScrollTests: XCTestCase {

	func testReturnsOnlyUnreadArticles() {
		let readArticle = makeArticle(articleID: "read", read: true)
		let unreadArticle = makeArticle(articleID: "unread", read: false)

		var handled = Set<String>()
		let articlesToMark = MarkReadOnScroll.articlesToMark(in: [readArticle, unreadArticle], handledArticleIDs: &handled)

		XCTAssertEqual(articlesToMark.map { $0.articleID }, [unreadArticle.articleID])
	}

	func testMarksEachArticleOnlyOncePerScrollSession() {
		let article = makeArticle(articleID: "a1", read: false)

		var handled = Set<String>()
		let firstPass = MarkReadOnScroll.articlesToMark(in: [article], handledArticleIDs: &handled)
		let secondPass = MarkReadOnScroll.articlesToMark(in: [article], handledArticleIDs: &handled)

		XCTAssertEqual(firstPass.count, 1)
		XCTAssertTrue(secondPass.isEmpty)
	}

	func testAlreadyHandledIDsAreNotReturnedAgain() {
		let article = makeArticle(articleID: "a2", read: false)

		var handled: Set<String> = [article.articleID]
		let articlesToMark = MarkReadOnScroll.articlesToMark(in: [article], handledArticleIDs: &handled)

		XCTAssertTrue(articlesToMark.isEmpty)
	}

	func testEmptyTimelineReturnsNothing() {
		var handled = Set<String>()
		let articlesToMark = MarkReadOnScroll.articlesToMark(in: [], handledArticleIDs: &handled)

		XCTAssertTrue(articlesToMark.isEmpty)
		XCTAssertTrue(handled.isEmpty)
	}

	// MARK: - Helpers

	private func makeArticle(date: Date = Date(), articleID: String, read: Bool) -> Article {
		Article(accountID: "test-account",
				articleID: articleID,
				feedID: "test-feed",
				uniqueID: articleID,
				title: "Title",
				contentHTML: nil,
				contentText: nil,
				markdown: nil,
				url: nil,
				externalURL: nil,
				summary: nil,
				imageURL: nil,
				datePublished: date,
				dateModified: nil,
				authors: nil,
				status: ArticleStatus(articleID: articleID, read: read, starred: false, dateArrived: date))
	}
}
