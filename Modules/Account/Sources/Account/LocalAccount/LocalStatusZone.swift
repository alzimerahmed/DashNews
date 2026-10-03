//
//  LocalStatusZone.swift
//  Account
//
//  Created by DashNews on 2/14/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import CloudKit
import CloudKitSync

/// CloudKit zone holding the read/starred status of articles for local (OnDisk)
/// accounts. One record per article, named deterministically after the article
/// (see `LocalStatusRecord.recordName`), so both devices write the same record
/// and the newer `lastModified` timestamp wins.
///
/// This is deliberately status-only: no article content is uploaded for local
/// accounts, keeping the iCloud footprint small.
final class LocalStatusZone: CloudKitZone {

	var zoneID: CKRecordZone.ID

	weak var container: CKContainer?
	weak var database: CKDatabase?
	var delegate: CloudKitZoneDelegate?
	var fetchChangesPageHandler: CloudKitZoneFetchPageHandler?

	static let zoneName = "LocalStatus"

	init(container: CKContainer) {
		self.container = container
		self.database = container.privateCloudDatabase
		self.zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
	}

}
