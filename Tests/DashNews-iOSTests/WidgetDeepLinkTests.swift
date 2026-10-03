//
//  WidgetDeepLinkTests.swift
//  DashNewsTests
//
//  Created by DashNews on 3/6/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import XCTest
@testable import DashNews

final class WidgetDeepLinkTests: XCTestCase {

	func testAllDeepLinksUseRegisteredDashNewsScheme() {
		// Widget taps silently no-op when the scheme isn't registered —
		// the app's URL type is `dashnews`, not upstream's `nnw`.
		let cases: [WidgetDeepLink] = [
			.unread, .today, .starred, .icon,
			.unreadArticle(id: "a1"), .todayArticle(id: "a2"), .starredArticle(id: "a3")
		]
		for link in cases {
			XCTAssertEqual(link.url.scheme, "dashnews", "\(link) must use the registered dashnews scheme")
		}
	}
}
