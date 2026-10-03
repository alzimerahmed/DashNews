//
//  ArticleThemeDownloader.swift
//  ArticleThemeDownloader
//
//  Created by Stuart Breckenridge on 20/09/2021.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation
import Zip
import RSWeb

public final class ArticleThemeDownloader: Sendable {
	public static let shared = ArticleThemeDownloader()

	public enum ArticleThemeDownloaderError: LocalizedError {
		case downloadFailed
		case noThemeFile
		case tooLarge
		case unsupportedURLScheme
		case invalidArchive

		public var errorDescription: String? {
			switch self {
			case .downloadFailed:
				return "The DashNews theme could not be downloaded."
			case .noThemeFile:
				return "There is no DashNews theme available."
			case .tooLarge:
				return "The DashNews theme is too large."
			case .unsupportedURLScheme:
				return "A DashNews theme can be downloaded only from an http or https URL."
			case .invalidArchive:
				return "The DashNews theme archive is invalid."
			}
		}
	}

	private static let maximumThemeSize = 10_000_000

	private init() {}

	@MainActor public func downloadTheme(from url: URL) {
		guard url.isHTTPOrHTTPSURL() else {
			NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error": ArticleThemeDownloaderError.unsupportedURLScheme])
			return
		}

		NotificationCenter.default.post(name: .didBeginDownloadingTheme, object: nil)

		Task { @MainActor in
			do {
				let downloadResponse = try await Downloader.shared.download(url, userAgentStyle: .browser)
				guard let data = downloadResponse.data, !data.isEmpty,
					  let response = downloadResponse.response, response.statusIsOK else {
					throw ArticleThemeDownloaderError.downloadFailed
				}
				guard data.count <= Self.maximumThemeSize else {
					throw ArticleThemeDownloaderError.tooLarge
				}

				// handleFile expects a file whose .tmp name becomes the .zip name.
				let temporaryFileURL = FileManager.default.temporaryDirectory
					.appendingPathComponent(UUID().uuidString)
					.appendingPathExtension("tmp")
				try data.write(to: temporaryFileURL)
				try handleFile(at: temporaryFileURL)
			} catch {
				NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error": error])
			}
		}
	}

	public func handleFile(at location: URL) throws {
		createDownloadDirectoryIfRequired()
		let movedFileLocation = try moveTheme(from: location)
		let unzippedFileLocation = try unzipFile(at: movedFileLocation)
		NotificationCenter.default.post(name: .didEndDownloadingTheme, object: nil, userInfo: ["url": unzippedFileLocation])
	}

	/// Creates `Application Support/DashNews/Downloads` if needed.
	private func createDownloadDirectoryIfRequired() {
		try? FileManager.default.createDirectory(at: downloadDirectory(), withIntermediateDirectories: true, attributes: nil)
	}

	/// Moves the downloaded `.tmp` file to the `downloadDirectory` and renames it a `.zip`
	/// - Parameter location: The temporary file location.
	/// - Returns: Destination `URL`.
	private func moveTheme(from location: URL) throws -> URL {
		var tmpFileName = location.lastPathComponent
		tmpFileName = tmpFileName.replacingOccurrences(of: ".tmp", with: ".zip")
		let fileUrl = downloadDirectory().appendingPathComponent("\(tmpFileName)")
		try FileManager.default.moveItem(at: location, to: fileUrl)
		return fileUrl
	}

	/// Unzips the zip file
	/// - Parameter location: Location of the zip archive.
	/// - Returns: Enclosed `.nnwtheme` file.
	private func unzipFile(at location: URL) throws -> URL {
		do {
			let unzipDirectory = URL(fileURLWithPath: location.path.replacingOccurrences(of: ".zip", with: ""))
			let themeURL = try unzipTheme(at: location, to: unzipDirectory) // Unzips to folder in Application Support/DashNews/Downloads
			try FileManager.default.removeItem(at: location) // Delete zip in Cache
			return themeURL
		} catch {
			try? FileManager.default.removeItem(at: location)
			throw error
		}
	}

	/// Extracts a theme into `destination` and returns its `.nnwtheme`; throws if an entry escapes `destination` or no theme is present.
	func unzipTheme(at zipLocation: URL, to destination: URL) throws -> URL {
		try Zip.unzipFile(zipLocation, destination: destination, overwrite: true, password: nil, progress: nil, fileOutputHandler: nil)
		// The Zip library is pinned post-1.1.0 (zip-slip fix), but verify
		// anyway — a hostile archive must not write or link outside the
		// downloads directory.
		try validateExtractionStaysInside(destination)
		guard let themeFilePath = findThemeFile(in: destination.path) else {
			throw ArticleThemeDownloaderError.noThemeFile
		}
		return destination.appendingPathComponent(themeFilePath)
	}

	/// Performs a deep search of the unzipped directory to find the theme file.
	/// - Parameter searchPath: directory to search
	/// - Returns: optional `String`
	private func findThemeFile(in searchPath: String) -> String? {
		if let directoryContents = FileManager.default.enumerator(atPath: searchPath) {
			while let file = directoryContents.nextObject() as? String {
				if file.hasPrefix("__MACOSX/") {
					// logger.debug("Ignoring theme file in __MACOSX folder.")
					continue
				}
				if file.hasSuffix(".nnwtheme") {
					return file
				}
			}
		}

		return nil
	}

	/// Throws `invalidArchive` if any extracted entry or symlink target
	/// resolves outside `destination`.
	private func validateExtractionStaysInside(_ destination: URL) throws {
		guard let enumerator = FileManager.default.enumerator(atPath: destination.path) else {
			return
		}
		let root = destination.standardizedFileURL.path
		while let relativePath = enumerator.nextObject() as? String {
			let fileURL = destination.appendingPathComponent(relativePath)
			let standardized = fileURL.standardizedFileURL.path
			guard standardized == root || standardized.hasPrefix(root + "/") else {
				throw ArticleThemeDownloaderError.invalidArchive
			}
			// A symlink inside the archive may point outside root.
			if let linkTarget = try? FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path) {
				let resolved = URL(fileURLWithPath: linkTarget, relativeTo: fileURL.deletingLastPathComponent()).standardizedFileURL.path
				guard resolved == root || resolved.hasPrefix(root + "/") else {
					throw ArticleThemeDownloaderError.invalidArchive
				}
			}
		}
	}

	/// The download directory used by the theme downloader: `Application Support/DashNews/Downloads`
	/// - Returns: `URL`
	private func downloadDirectory() -> URL {
		FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("DashNews/Downloads", isDirectory: true)
	}

	/// Removes downloaded themes, where themes == folders, from `Application Support/DashNews/Downloads`.
	public func cleanUp() {
		guard let filenames = try? FileManager.default.contentsOfDirectory(atPath: downloadDirectory().path) else {
			return
		}
		for path in filenames {
			do {
				if FileManager.default.isFolder(atPath: downloadDirectory().appendingPathComponent(path).path) {
					try FileManager.default.removeItem(atPath: downloadDirectory().appendingPathComponent(path).path)
				}
			} catch {
				print(error)
			}
		}
	}
}
