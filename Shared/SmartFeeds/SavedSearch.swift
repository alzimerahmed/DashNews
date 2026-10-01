//
//  SavedSearch.swift
//  NetNewsWire
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import os
import RSCore

/// A user-saved search query that appears as a smart feed in the sidebar.
/// Feature #7 — saved searches. Persisted as JSON in the app data folder.
struct SavedSearch: Codable, Hashable, Sendable, Identifiable {

	let id: UUID
	var name: String
	let searchString: String
	let dateCreated: Date

	init(id: UUID = UUID(), name: String, searchString: String, dateCreated: Date = Date()) {
		self.id = id
		self.name = name
		self.searchString = searchString
		self.dateCreated = dateCreated
	}
}

/// Loads and saves the list of saved searches from a JSON file.
/// The file URL is injectable so persistence logic can be unit tested.
/// All access is main-thread only, matching the rest of the app-layer state.
@MainActor final class SavedSearchStore {

	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "SavedSearchStore")

	private(set) var savedSearches: [SavedSearch]
	private let fileURL: URL

	static func defaultFileURL() -> URL {
		AppConfig.dataFolder.appendingPathComponent("SavedSearches.json")
	}

	init(fileURL: URL = SavedSearchStore.defaultFileURL()) {
		self.fileURL = fileURL
		self.savedSearches = SavedSearchStore.loadSavedSearches(from: fileURL)
	}

	/// Adds a saved search. Does nothing if the exact same search string is already saved.
	/// Returns nil if the search string is empty or whitespace-only.
	/// Returns the saved search, whether newly created or pre-existing.
	@discardableResult
	func add(name: String, searchString: String) -> SavedSearch? {
		let trimmedSearchString = searchString.trimmingWhitespace
		guard !trimmedSearchString.isEmpty else {
			return nil
		}
		if let existing = savedSearch(searchString: trimmedSearchString) {
			return existing
		}
		let trimmedName = name.isEmpty ? trimmedSearchString : name
		let savedSearch = SavedSearch(name: trimmedName, searchString: trimmedSearchString)
		savedSearches.append(savedSearch)
		save()
		return savedSearch
	}

	func rename(id: UUID, to name: String) {
		guard let index = savedSearches.firstIndex(where: { $0.id == id }) else {
			return
		}
		let trimmedName = name.trimmingWhitespace
		guard !trimmedName.isEmpty else {
			return
		}
		savedSearches[index].name = trimmedName
		save()
	}

	func remove(id: UUID) {
		savedSearches.removeAll { $0.id == id }
		save()
	}

	func savedSearch(id: UUID) -> SavedSearch? {
		savedSearches.first { $0.id == id }
	}

	func savedSearch(searchString: String) -> SavedSearch? {
		savedSearches.first { $0.searchString == searchString }
	}
}

// MARK: - Private

private extension SavedSearchStore {

	static let jsonEncoder = JSONEncoder()

	static func loadSavedSearches(from fileURL: URL) -> [SavedSearch] {
		guard let data = try? Data(contentsOf: fileURL) else {
			return []
		}
		do {
			return try JSONDecoder().decode([SavedSearch].self, from: data)
		} catch {
			Self.logger.error("SavedSearchStore: could not decode \(fileURL.path, privacy: .public) — \(error, privacy: .public)")
			assertionFailure("SavedSearchStore: could not decode \(fileURL.path) — \(error)")
			return []
		}
	}

	func save() {
		do {
			let data = try Self.jsonEncoder.encode(savedSearches)
			try data.write(to: fileURL, options: .atomic)
		} catch {
			Self.logger.error("SavedSearchStore: could not save \(fileURL.path, privacy: .public) — \(error, privacy: .public)")
			assertionFailure("SavedSearchStore: could not save \(fileURL.path) — \(error)")
		}
	}
}
