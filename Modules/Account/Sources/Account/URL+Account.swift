//
//  URL+Account.swift
//  DashNews
//
//  Created by DashNews on 3/6/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation

public extension URL {

	/// True when the host is on the local device or a private network —
	/// localhost, loopback, mDNS/intranet suffixes, or a private/link-local
	/// IPv4 literal. Custom sync endpoints (FreshRSS and other self-hosted
	/// Reader API servers) on private hosts may legitimately use plain
	/// `http`; endpoints on public hosts must use `https` so credentials
	/// never travel in cleartext.
	var isPrivateNetworkHost: Bool {
		guard let host = host?.lowercased() else {
			return false
		}
		if host == "localhost" || host == "::1" || host == "[::1]" {
			return true
		}
		for suffix in [".local", ".lan", ".home", ".internal", ".corp"] {
			if host.hasSuffix(suffix) {
				return true
			}
		}
		let octets = host.split(separator: ".").compactMap { Int($0) }
		guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else {
			return false
		}
		switch octets[0] {
		case 10, 127:
			return true
		case 169:
			return octets[1] == 254
		case 172:
			return (16...31).contains(octets[1])
		case 192:
			return octets[1] == 168
		default:
			return false
		}
	}
}
