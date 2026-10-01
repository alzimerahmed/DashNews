//
//  SmartFeedLaunchSelectionTests.swift
//  NetNewsWireTests
//
//  Created by DashNews on 2/13/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import XCTest
@testable import DashNews

final class SmartFeedLaunchSelectionTests: XCTestCase {

	func testFirstRunWithoutSavedSelectionSelectsAllUnread() {
		let selection = SmartFeedLaunchSelection.defaultSelection(isFirstRun: true, hasSavedSelection: false)

		XCTAssertEqual(selection, .allUnread)
	}

	func testFirstRunWithSavedSelectionRestoresInstead() {
		let selection = SmartFeedLaunchSelection.defaultSelection(isFirstRun: true, hasSavedSelection: true)

		XCTAssertNil(selection)
	}

	func testLaterLaunchWithoutSavedSelectionDoesNotForceAllUnread() {
		let selection = SmartFeedLaunchSelection.defaultSelection(isFirstRun: false, hasSavedSelection: false)

		XCTAssertNil(selection)
	}

	func testLaterLaunchWithSavedSelectionRestores() {
		let selection = SmartFeedLaunchSelection.defaultSelection(isFirstRun: false, hasSavedSelection: true)

		XCTAssertNil(selection)
	}
}
