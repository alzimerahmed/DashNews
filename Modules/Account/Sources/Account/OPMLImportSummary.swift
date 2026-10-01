//
//  OPMLImportSummary.swift
//  Account
//
//  Created by DashNews on 2/13/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation

/// Summary of a completed OPML import.
public struct OPMLImportSummary: Sendable {

	/// Feeds skipped because the account already subscribes to the same feed URL.
	public let duplicatesSkipped: Int

	public init(duplicatesSkipped: Int) {
		self.duplicatesSkipped = duplicatesSkipped
	}
}
