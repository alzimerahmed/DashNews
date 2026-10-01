//
//  SavedSearchStoreTests.swift
//  NetNewsWireTests
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import XCTest
@testable import DashNews

@MainActor final class SavedSearchStoreTests: XCTestCase {

	// XCTest calls setUp/tearDown from a nonisolated context; all access is
	// still on the main thread, so the unsafe annotation is sound here.
	nonisolated(unsafe) private var fileURL: URL!

	override func setUp() {
		super.setUp()
		fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("saved-searches-\(UUID().uuidString).json")
	}

	override func tearDown() {
		try? FileManager.default.removeItem(at: fileURL)
		super.tearDown()
	}

	func testAddPersistsAcrossStoreRecreation() {
		let store = SavedSearchStore(fileURL: fileURL)
		store.add(name: "Swift News", searchString: "swift")

		let reloadedStore = SavedSearchStore(fileURL: fileURL)
		XCTAssertEqual(reloadedStore.savedSearches.count, 1)
		XCTAssertEqual(reloadedStore.savedSearches.first?.name, "Swift News")
		XCTAssertEqual(reloadedStore.savedSearches.first?.searchString, "swift")
	}

	func testAddSameSearchStringDoesNotDuplicate() throws {
		let store = SavedSearchStore(fileURL: fileURL)
		let first = try XCTUnwrap(store.add(name: "One", searchString: "swift"))
		let second = try XCTUnwrap(store.add(name: "Two", searchString: "swift"))

		XCTAssertEqual(store.savedSearches.count, 1)
		XCTAssertEqual(first.id, second.id)
	}

	func testAddEmptySearchStringIsIgnored() {
		let store = SavedSearchStore(fileURL: fileURL)
		store.add(name: "Empty", searchString: "   ")

		XCTAssertTrue(store.savedSearches.isEmpty)
	}

	func testRenameUpdatesName() throws {
		let store = SavedSearchStore(fileURL: fileURL)
		let savedSearch = try XCTUnwrap(store.add(name: "Original", searchString: "swift"))

		store.rename(id: savedSearch.id, to: "Renamed")

		XCTAssertEqual(store.savedSearch(id: savedSearch.id)?.name, "Renamed")
	}

	func testRenameToEmptyNameIsIgnored() throws {
		let store = SavedSearchStore(fileURL: fileURL)
		let savedSearch = try XCTUnwrap(store.add(name: "Original", searchString: "swift"))

		store.rename(id: savedSearch.id, to: "   ")

		XCTAssertEqual(store.savedSearch(id: savedSearch.id)?.name, "Original")
	}

	func testRemoveDeletesSavedSearch() throws {
		let store = SavedSearchStore(fileURL: fileURL)
		let savedSearch = try XCTUnwrap(store.add(name: "Temp", searchString: "swift"))

		store.remove(id: savedSearch.id)

		XCTAssertTrue(store.savedSearches.isEmpty)
		XCTAssertNil(store.savedSearch(id: savedSearch.id))
	}

	func testRemovePersistsAcrossStoreRecreation() throws {
		let store = SavedSearchStore(fileURL: fileURL)
		let savedSearch = try XCTUnwrap(store.add(name: "Temp", searchString: "swift"))
		store.remove(id: savedSearch.id)

		let reloadedStore = SavedSearchStore(fileURL: fileURL)

		XCTAssertTrue(reloadedStore.savedSearches.isEmpty)
	}

	func testCorruptFileLoadsAsEmpty() throws {
		try Data("not json".utf8).write(to: fileURL)

		let store = SavedSearchStore(fileURL: fileURL)

		XCTAssertTrue(store.savedSearches.isEmpty)
	}
}
