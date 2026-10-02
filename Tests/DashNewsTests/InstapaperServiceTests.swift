//
//  InstapaperServiceTests.swift
//  DashNewsTests
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import XCTest
@testable import DashNews

final class InstapaperServiceTests: XCTestCase {

	func testRequestBodyIncludesRequiredFields() {
		let body = InstapaperService.requestBody(username: "user", password: "pass", url: "https://example.com/a", title: "Title")
		XCTAssertEqual(body, "username=user&password=pass&url=https%3A%2F%2Fexample.com%2Fa&title=Title")
	}

	func testRequestBodyOmitsEmptyTitle() {
		let body = InstapaperService.requestBody(username: "user", password: "pass", url: "https://example.com/a", title: "   ")
		XCTAssertFalse(body.contains("title="))
	}

	func testFormEncodesSpecialCharacters() {
		let encoded = InstapaperService.formEncode("a b&c=d/e?f+g")
		XCTAssertEqual(encoded, "a%20b%26c%3Dd%2Fe%3Ff%2Bg")
	}

	func testFormEncodesUnicode() {
		let encoded = InstapaperService.formEncode("héllo")
		XCTAssertEqual(encoded, "h%C3%A9llo")
	}
}
