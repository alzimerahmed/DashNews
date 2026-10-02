//
//  FeedIntelligenceStore.swift
//  DashNews
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import os
import RSCore

/// Per-feed on-device intelligence settings. Feature #8.
struct FeedIntelligenceSettings: Codable, Hashable, Sendable {

	var highlightKeyPoints: Bool

	/// The settings a feed gets when nothing has been stored for it.
	static let off = FeedIntelligenceSettings(highlightKeyPoints: false)
}

/// Loads and saves per-feed intelligence settings from a JSON file keyed by
/// feedID. Same persistence pattern as KeywordRuleStore: injectable file URL
/// so persistence can be unit tested, atomic writes, corrupt-file recovery.
/// All access is main-thread only, matching the rest of the app-layer state.
@MainActor final class FeedIntelligenceStore: ObservableObject {

	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "FeedIntelligenceStore")

	@Published private(set) var settingsByFeedID: [String: FeedIntelligenceSettings]

	private let fileURL: URL

	static func defaultFileURL() -> URL {
		AppConfig.dataFolder.appendingPathComponent("FeedIntelligence.json")
	}

	static let shared = FeedIntelligenceStore()

	init(fileURL: URL = FeedIntelligenceStore.defaultFileURL()) {
		self.fileURL = fileURL
		self.settingsByFeedID = FeedIntelligenceStore.loadSettings(from: fileURL)
	}

	func settings(forFeedID feedID: String) -> FeedIntelligenceSettings {
		settingsByFeedID[feedID] ?? .off
	}

	func highlightKeyPoints(forFeedID feedID: String) -> Bool {
		settings(forFeedID: feedID).highlightKeyPoints
	}

	func setHighlightKeyPoints(_ flag: Bool, forFeedID feedID: String) {
		var feedSettings = settings(forFeedID: feedID)
		feedSettings.highlightKeyPoints = flag
		if feedSettings == .off {
			// Keep the file sparse: don't persist all-default entries.
			settingsByFeedID.removeValue(forKey: feedID)
		} else {
			settingsByFeedID[feedID] = feedSettings
		}
		save()
	}
}

// MARK: - Private

private extension FeedIntelligenceStore {

	static let jsonEncoder = JSONEncoder()

	static func loadSettings(from fileURL: URL) -> [String: FeedIntelligenceSettings] {
		guard let data = try? Data(contentsOf: fileURL) else {
			return [:]
		}
		do {
			return try JSONDecoder().decode([String: FeedIntelligenceSettings].self, from: data)
		} catch {
			// A corrupt or unreadable file is recoverable: settings reset
			// to defaults rather than crashing the app.
			Self.logger.error("FeedIntelligenceStore: could not decode \(fileURL.path, privacy: .public) — \(error, privacy: .public)")
			return [:]
		}
	}

	func save() {
		do {
			let data = try Self.jsonEncoder.encode(settingsByFeedID)
			try data.write(to: fileURL, options: .atomic)
		} catch {
			Self.logger.error("FeedIntelligenceStore: could not save \(self.fileURL.path, privacy: .public) — \(error, privacy: .public)")
		}
		// Cached key sentences can depend on these settings; drop them so a
		// toggle takes effect on the next render.
		KeySentenceCache.shared.removeAll()
	}
}
