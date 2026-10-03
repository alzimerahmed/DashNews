//
//  HelpURL.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/29/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation

enum HelpURL: String {

	case helpHome = "https://github.com/alzimerahmed/DashNews#readme"
	case website = "https://github.com/alzimerahmed/DashNews"
	case releaseNotes = "https://github.com/alzimerahmed/DashNews/releases"
	case githubRepo = "https://github.com/alzimerahmed/DashNews"
	case bugTracker = "https://github.com/alzimerahmed/DashNews/issues"
	case technotes = "https://github.com/alzimerahmed/DashNews/tree/main/Technotes"
	case privacyPolicy = "https://github.com/alzimerahmed/DashNews/blob/main/Technotes/PrivacyPolicy.markdown"

#if os(macOS)
	@MainActor func open() {
		Browser.open(self.rawValue, inBackground: false)
	}
#endif
}
