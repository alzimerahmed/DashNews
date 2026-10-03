//
//  InstapaperService.swift
//  DashNews
//
//  Created by DashNews on 10/3/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import os
import RSCore
import Secrets

/// Read-later integration with Instapaper. Feature #3.
///
/// Decision record (docs/research.md): Instapaper first — Pocket's API was shut
/// down to new apps in 2025 and Readwise Reader's API is read-only for saves.
/// Uses Instapaper's simple HTTPS add API (username/password form POST); the
/// password is stored in the keychain via CredentialsManager, the username in
/// UserDefaults. No credentials are ever committed to the repository.
enum InstapaperService {

	static let server = "www.instapaper.com"
	static let apiURLString = "https://www.instapaper.com/api/add"
	private static let usernameDefaultsKey = "instapaperUsername"
	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "InstapaperService")

	enum InstapaperError: LocalizedError {
		case notConfigured
		case authenticationFailed
		case requestFailed(status: Int)

		var errorDescription: String? {
			switch self {
			case .notConfigured:
				return NSLocalizedString("Instapaper account is not configured.", comment: "Instapaper error: account not configured")
			case .authenticationFailed:
				return NSLocalizedString("Instapaper rejected the username or password.", comment: "Instapaper error: authentication failed")
			case .requestFailed(let status):
				return String.localizedStringWithFormat(NSLocalizedString("Instapaper request failed with status %d.", comment: "Instapaper error: request failed with HTTP status"), status)
			}
		}
	}

	/// True when a username is set. The keychain password may still be missing;
	/// sending will surface that as an authentication failure.
	static var isConfigured: Bool {
		username != nil
	}

	static var username: String? {
		let stored = UserDefaults.standard.string(forKey: usernameDefaultsKey)
		let trimmed = stored?.trimmingWhitespace
		if let trimmed, trimmed.isEmpty {
			return nil
		}
		return trimmed
	}

	static func saveCredentials(username: String, password: String) throws {
		let trimmedUsername = username.trimmingWhitespace
		guard !trimmedUsername.isEmpty else {
			throw InstapaperError.notConfigured
		}
		UserDefaults.standard.set(trimmedUsername, forKey: usernameDefaultsKey)
		let credentials = Credentials(type: .basic, username: trimmedUsername, secret: password)
		try CredentialsManager.storeCredentials(credentials, server: server)
	}

	static func removeCredentials() {
		guard let username else {
			return
		}
		UserDefaults.standard.removeObject(forKey: usernameDefaultsKey)
		do {
			try CredentialsManager.removeCredentials(type: .basic, server: server, username: username)
		} catch {
			// An orphaned keychain entry isn't fatal — the username is gone,
			// so isConfigured reads false — but the failure should be visible.
			logger.error("InstapaperService: keychain removal failed — \(error.localizedDescription, privacy: .public)")
		}
	}

	/// Sends the article URL to Instapaper. Throws on failure.
	static func send(url: URL, title: String?) async throws {
		guard let username, let credentials = try CredentialsManager.retrieveCredentials(type: .basic, server: server, username: username) else {
			throw InstapaperError.notConfigured
		}
		// apiURLString is a compile-time constant HTTPS URL; a nil result
		// would mean the constant was corrupted, not a runtime error.
		guard let apiURL = URL(string: apiURLString) else {
			logger.error("InstapaperService: apiURLString is not a valid URL")
			return
		}

		var request = URLRequest(url: apiURL)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		request.httpBody = requestBody(username: username, password: credentials.secret, url: url.absoluteString, title: title).data(using: .utf8)

		// Ephemeral session — the shared session's default cookie storage
		// must not attach app cookies to authenticated Instapaper calls.
		let session = URLSession(configuration: .ephemeral)
		let (_, response) = try await session.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw InstapaperError.requestFailed(status: -1)
		}
		switch httpResponse.statusCode {
		case 200, 201:
			return
		case 401, 403:
			throw InstapaperError.authenticationFailed
		default:
			logger.error("InstapaperService: add failed — status \(httpResponse.statusCode, privacy: .public)")
			throw InstapaperError.requestFailed(status: httpResponse.statusCode)
		}
	}

	/// Builds the form-encoded request body. Pure so it can be unit tested.
	static func requestBody(username: String, password: String, url: String, title: String?) -> String {
		var pairs = [
			"username=\(formEncode(username))",
			"password=\(formEncode(password))",
			"url=\(formEncode(url))"
		]
		if let title, !title.trimmingWhitespace.isEmpty {
			pairs.append("title=\(formEncode(title))")
		}
		return pairs.joined(separator: "&")
	}

	/// Percent-encodes a form field value. ASCII-strict so non-ASCII
	/// characters (e.g. accented letters) are always encoded.
	static func formEncode(_ value: String) -> String {
		let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
		return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
	}
}
