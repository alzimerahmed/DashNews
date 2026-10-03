//
//  SmartFeedLaunchSelection.swift
//  DashNews
//
//  Created by DashNews on 2/13/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation

/// Decides which smart feed should be selected when the app launches with no
/// saved sidebar selection. First-run users land in the "All Unread" smart
/// inbox so they see one stream instead of an empty-feeling sidebar.
enum SmartFeedLaunchSelection {

	enum DefaultSmartFeed {
		case today
		case allUnread
		case starred
	}

	/// Returns the smart feed to select at launch on the very first run,
	/// or `nil` when a saved selection should be restored instead.
	static func defaultSelection(isFirstRun: Bool) -> DefaultSmartFeed? {
		guard isFirstRun else {
			return nil
		}
		return .allUnread
	}
}
