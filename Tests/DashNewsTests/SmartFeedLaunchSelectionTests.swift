//
//  SmartFeedLaunchSelectionTests.swift
//  DashNewsTests
//
//  Created by DashNews on 2/13/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import XCTest
@testable import DashNews

final class SmartFeedLaunchSelectionTests: XCTestCase {

	func testFirstRunSelectsAllUnread() {
		let selection = SmartFeedLaunchSelection.defaultSelection(isFirstRun: true)

		XCTAssertEqual(selection, .allUnread)
	}

	func testLaterLaunchRestoresSavedSelection() {
		let selection = SmartFeedLaunchSelection.defaultSelection(isFirstRun: false)

		XCTAssertNil(selection)
	}
}
