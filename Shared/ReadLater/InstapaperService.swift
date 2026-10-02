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
				return "Instapaper account is not configured."
			case .authenticationFailed:
				return "Instapaper rejected the username or password."
			case .requestFailed(let status):
				return "Instapaper request failed with status \(status)."
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
		try? CredentialsManager.removeCredentials(type: .basic, server: server, username: username)
	}

	/// Sends the article URL to Instapaper. Throws on failure.
	static func send(url: URL, title: String?) async throws {
		guard let username, let credentials = try CredentialsManager.retrieveCredentials(type: .basic, server: server, username: username) else {
			throw InstapaperError.notConfigured
		}
		guard let apiURL = URL(string: apiURLString) else {
			throw InstapaperError.requestFailed(status: -1)
		}

		var request = URLRequest(url: apiURL)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		request.httpBody = requestBody(username: username, password: credentials.secret, url: url.absoluteString, title: title).data(using: .utf8)

		let (_, response) = try await URLSession.shared.data(for: request)
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
