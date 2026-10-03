//
//  CrashReporter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Foundation
import RSCore
import CrashReporter

// Displays a window that shows the crash log — gives the user the chance to add data.
// (Or just decide not to send it.)
// This code is not included in the MAS build.
// At some point this code should probably move into RSCore, so Rainier and any other
// future apps can use it.

@MainActor struct CrashReporter {

	struct DefaultsKey {
		static let sendCrashLogsAutomaticallyKey = "SendCrashLogsAutomatically"
	}

	private static var crashReportWindowController: CrashReportWindowController?

	/// Look in ~/Library/Logs/DiagnosticReports/ for a new crash log for this app.
	/// Show a crash log reporter window if found.
	static func check(crashReporter: PLCrashReporter) {
		guard !Platform.isRunningUnitTests else {
			return
		}
		guard crashReporter.hasPendingCrashReport(),
			  let crashData = crashReporter.loadPendingCrashReportData(),
			  let crashReport = try? PLCrashReport(data: crashData),
			  let crashLogText = PLCrashReportTextFormatter.stringValue(for: crashReport, with: PLCrashReportTextFormatiOS) else { return }

		if shouldSendCrashLogsAutomatically() {
			sendCrashLogText(crashLogText)
		} else {
			runCrashReporterWindow(crashLogText)
		}

		crashReporter.purgePendingCrashReport()
	}

	/// There is no DashNews crash-report server — the upstream endpoint was
	/// removed. "Send" copies the log to the clipboard and opens the issue
	/// tracker so the user can paste it into a bug report themselves.
	static func sendCrashLogText(_ crashLogText: String) {
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(crashLogText, forType: .string)
		HelpURL.bugTracker.open()
	}

	static func runCrashReporterWindow(_ crashLogText: String) {
		crashReportWindowController = CrashReportWindowController(crashLogText: crashLogText)
		crashReportWindowController!.showWindow(self)
	}
}

private extension CrashReporter {

	static func shouldSendCrashLogsAutomatically() -> Bool {
		return UserDefaults.standard.bool(forKey: DefaultsKey.sendCrashLogsAutomaticallyKey)
	}
}
