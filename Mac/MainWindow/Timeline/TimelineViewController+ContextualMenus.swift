//
//  TimelineViewController+ContextualMenus.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/9/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import SwiftUI
import RSCore
import Articles
import Account

extension TimelineViewController {

	func contextualMenuForClickedRows() -> NSMenu? {

		let row = tableView.clickedRow
		guard row != -1, let article = articles.articleAtRow(row) else {
			return nil
		}

		if selectedArticles.contains(article) {
			// If the clickedRow is part of the selected rows, then do a contextual menu for all the selected rows.
			return menu(for: selectedArticles)
		}
		return menu(for: [article])
	}
}

// MARK: Contextual Menu Actions

extension TimelineViewController {

	@objc func markArticlesReadFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markArticles(articles, read: true)
	}

	@objc func markArticlesUnreadFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markArticles(articles, read: false)
	}

	@objc func markAboveArticlesReadFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markAboveArticlesRead(articles)
	}

	@objc func markBelowArticlesReadFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markBelowArticlesRead(articles)
	}

	@objc func markArticlesStarredFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markArticles(articles, starred: true)
	}

	@objc func markArticlesUnstarredFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else {
			return
		}
		markArticles(articles, starred: false)
	}

	@objc func selectFeedInSidebarFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let feed = menuItem.representedObject as? Feed else {
			return
		}
		delegate?.timelineRequestedFeedSelection(self, feed: feed)
	}

	@objc func markAllInFeedAsRead(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem,
			  let feed = menuItem.representedObject as? Feed else {
			return
		}

		let unreadArticles = feed.fetchUnreadArticles()
		guard !unreadArticles.isEmpty else {
			return
		}
		guard let undoManager, let markReadCommand = MarkStatusCommand(
			initialArticles: Array(unreadArticles),
			markingRead: true,
			undoManager: undoManager
		) else {
			return
		}

		runCommand(markReadCommand)
	}

	@objc func openInBrowserFromContextualMenu(_ sender: Any?) {

		guard let menuItem = sender as? NSMenuItem, let urlString = menuItem.representedObject as? String else {
			return
		}
		Browser.open(urlString, inBackground: false)
	}

	@objc func copyURLFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let urlString = menuItem.representedObject as? String else {
			return
		}
		URLPasteboardWriter.write(urlString: urlString, to: .general)
	}

	@objc func performShareServiceFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let sharingCommandInfo = menuItem.representedObject as? SharingCommandInfo else {
			return
		}
		sharingCommandInfo.perform()
	}

	@objc func sendToInstapaperFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let urlString = menuItem.representedObject as? String, let url = URL(string: urlString) else {
			return
		}

		let send: () -> Void = {
			Task { @MainActor in
				do {
					try await InstapaperService.send(url: url, title: nil)
				} catch {
					NSApplication.shared.presentError(error)
				}
			}
		}

		guard InstapaperService.isConfigured else {
			presentInstapaperCredentialsPrompt(completion: send)
			return
		}
		send()
	}

	@objc func summarizeArticleFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem,
			  let article = menuItem.representedObject as? Article,
			  let window = view.window else {
			return
		}
		let hostingController = NSHostingController(rootView: ArticleSummaryView(title: article.title, contentText: article.summarizableText))
		let summaryWindow = NSWindow(contentViewController: hostingController)
		summaryWindow.styleMask = [.titled, .closable, .resizable]
		summaryWindow.setContentSize(NSSize(width: 520, height: 560))
		window.beginSheet(summaryWindow)
	}

	@objc func translateArticleFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem,
			  let article = menuItem.representedObject as? Article,
			  let window = view.window else {
			return
		}
		guard #available(iOS 18.0, macOS 15.0, *) else {
			return
		}
		let text = KeywordRuleMatcher.searchableText(of: article)
		guard !text.isEmpty else {
			return
		}
		let hostingController = NSHostingController(rootView: ArticleTranslationView(sourceText: text))
		let translationWindow = NSWindow(contentViewController: hostingController)
		translationWindow.styleMask = [.titled, .closable, .resizable]
		translationWindow.setContentSize(NSSize(width: 520, height: 560))
		window.beginSheet(translationWindow)
	}

	func presentInstapaperCredentialsPrompt(completion: @escaping () -> Void) {
		let alert = NSAlert()
		alert.messageText = NSLocalizedString("Instapaper Account", comment: "Instapaper account setup title")
		alert.informativeText = NSLocalizedString("Enter your Instapaper username and password to save articles for later.", comment: "Instapaper account setup message")
		alert.addButton(withTitle: NSLocalizedString("Save", comment: "Save button"))
		alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button"))

		let usernameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
		usernameField.placeholderString = NSLocalizedString("Username", comment: "Username")
		let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
		passwordField.placeholderString = NSLocalizedString("Password", comment: "Password")
		let stack = NSStackView(views: [NSTextField(labelWithString: NSLocalizedString("Username", comment: "Username")), usernameField, NSTextField(labelWithString: NSLocalizedString("Password", comment: "Password")), passwordField])
		stack.orientation = .vertical
		stack.alignment = .leading
		stack.spacing = 6.0
		stack.frame = NSRect(x: 0, y: 0, width: 240, height: 110)
		alert.accessoryView = stack

		guard let window = view.window else {
			return
		}
		alert.beginSheetModal(for: window) { response in
			guard response == .alertFirstButtonReturn else {
				return
			}
			do {
				try InstapaperService.saveCredentials(username: usernameField.stringValue, password: passwordField.stringValue)
				completion()
			} catch {
				NSApplication.shared.presentError(error)
			}
		}
	}
}

private extension TimelineViewController {

	func markArticles(_ articles: [Article], read: Bool) {
		markArticles(articles, statusKey: .read, flag: read)
	}

	func markArticles(_ articles: [Article], starred: Bool) {
		markArticles(articles, statusKey: .starred, flag: starred)
	}

	func markArticles(_ articles: [Article], statusKey: ArticleStatus.Key, flag: Bool) {
		guard let undoManager = undoManager, let markStatusCommand = MarkStatusCommand(initialArticles: articles, statusKey: statusKey, flag: flag, undoManager: undoManager) else {
			return
		}

		runCommand(markStatusCommand)
	}

	func unreadArticles(from articles: [Article]) -> [Article]? {
		let filteredArticles = articles.filter { !$0.status.read }
		return filteredArticles.isEmpty ? nil : filteredArticles
	}

	func readArticles(from articles: [Article]) -> [Article]? {
		let filteredArticles = articles.filter { $0.status.read }
		return filteredArticles.isEmpty ? nil : filteredArticles
	}

	func articles(from sender: Any?) -> [Article]? {
		return (sender as? NSMenuItem)?.representedObject as? [Article]
	}

	func menu(for articles: [Article]) -> NSMenu? {
		let menu = NSMenu(title: "")

		if articles.anyArticleIsUnread() {
			menu.addItem(markReadMenuItem(articles))
		}
		if articles.anyArticleIsReadAndCanMarkUnread() {
			menu.addItem(markUnreadMenuItem(articles))
		}
		if articles.anyArticleIsUnstarred() {
			menu.addItem(markStarredMenuItem(articles))
		}
		if articles.anyArticleIsStarred() {
			menu.addItem(markUnstarredMenuItem(articles))
		}
		if let first = articles.first, self.articles.articlesAbove(article: first).canMarkAllAsRead() {
			menu.addItem(markAboveReadMenuItem(articles))
		}
		if let last = articles.last, self.articles.articlesBelow(article: last).canMarkAllAsRead() {
			menu.addItem(markBelowReadMenuItem(articles))
		}

		menu.addSeparatorIfNeeded()

		if articles.count == 1, let feed = articles.first!.feed {
			if !(representedObjects?.contains(where: { $0 as? Feed == feed }) ?? false) {
				menu.addItem(selectFeedInSidebarMenuItem(feed))
			}
			if let markAllMenuItem = markAllAsReadMenuItem(feed) {
				menu.addItem(markAllMenuItem)
			}
		}

		if articles.count == 1, let link = articles.first!.preferredLink {
			menu.addSeparatorIfNeeded()
			menu.addItem(openInBrowserMenuItem(link))
			menu.addItem(menuItem(NSLocalizedString("Send to Instapaper", comment: "Command"), #selector(sendToInstapaperFromContextualMenu(_:)), link))
			menu.addSeparatorIfNeeded()
			menu.addItem(copyArticleURLMenuItem(link))

			if let externalLink = articles.first?.externalLink, externalLink != link {
				menu.addItem(copyExternalURLMenuItem(externalLink))
			}
		}

		if articles.count == 1, let singleArticle = articles.first {
			menu.addSeparatorIfNeeded()
			menu.addItem(menuItem(NSLocalizedString("Summarize Article", comment: "Command"), #selector(summarizeArticleFromContextualMenu(_:)), singleArticle))
			menu.addItem(menuItem(NSLocalizedString("Translate Article", comment: "Command"), #selector(translateArticleFromContextualMenu(_:)), singleArticle))
		}

		menu.addSeparatorIfNeeded()
		let shareButtonMenuItem = NSMenuItem(title: NSLocalizedString("Share…", comment: "Share…"), action: #selector(showShareSheet(_:)), keyEquivalent: "")
		shareButtonMenuItem.target = self
		shareButtonMenuItem.representedObject = articles
		menu.addItem(shareButtonMenuItem)
		shareButtonMenuItem.isEnabled = !articles.isEmpty

		return menu
	}

	@objc func showShareSheet(_ sender: Any?) {
		let articlesToShare: [Article]
		if let menuItem = sender as? NSMenuItem, let representedArticles = menuItem.representedObject as? [Article] {
			articlesToShare = representedArticles
		} else {
			articlesToShare = selectedArticles
		}
		let sortedArticles = articlesToShare.sortedByDate(.orderedAscending)
		let items = sortedArticles.map { ArticlePasteboardWriter(article: $0) }
		let sharingServicePicker = NSSharingServicePicker(items: items)
		sharingServicePicker.delegate = self.sharingServicePickerDelegate

		// Anchor the picker to the first article being shared
		let rowToAnchorTo: Int
		if let firstArticle = articlesToShare.first,
		   let row = articles.firstIndex(where: { $0.articleID == firstArticle.articleID }) {
			rowToAnchorTo = row
		} else {
			rowToAnchorTo = tableView.selectedRow
		}
		let rect = tableView.rect(ofRow: rowToAnchorTo)
		sharingServicePicker.show(relativeTo: rect, of: tableView, preferredEdge: .maxX)
	}

	func markReadMenuItem(_ articles: [Article]) -> NSMenuItem {
		menuItem(NSLocalizedString("Mark as Read", comment: "Command"), #selector(markArticlesReadFromContextualMenu(_:)), articles)
	}

	func markUnreadMenuItem(_ articles: [Article]) -> NSMenuItem {
		menuItem(NSLocalizedString("Mark as Unread", comment: "Command"), #selector(markArticlesUnreadFromContextualMenu(_:)), articles)
	}

	func markStarredMenuItem(_ articles: [Article]) -> NSMenuItem {
		menuItem(NSLocalizedString("Mark as Starred", comment: "Command"), #selector(markArticlesStarredFromContextualMenu(_:)), articles)
	}

	func markUnstarredMenuItem(_ articles: [Article]) -> NSMenuItem {
		menuItem(NSLocalizedString("Mark as Unstarred", comment: "Command"), #selector(markArticlesUnstarredFromContextualMenu(_:)), articles)
	}

	func markAboveReadMenuItem(_ articles: [Article]) -> NSMenuItem {
		menuItem(NSLocalizedString("Mark Above as Read", comment: "Command"), #selector(markAboveArticlesReadFromContextualMenu(_:)), articles)
	}

	func markBelowReadMenuItem(_ articles: [Article]) -> NSMenuItem {
		menuItem(NSLocalizedString("Mark Below as Read", comment: "Command"), #selector(markBelowArticlesReadFromContextualMenu(_:)), articles)
	}

	func selectFeedInSidebarMenuItem(_ feed: Feed) -> NSMenuItem {
		let localizedMenuText = NSLocalizedString("Select “%@” in Sidebar", comment: "Command")
		let formattedMenuText = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay)
		return menuItem(formattedMenuText as String, #selector(selectFeedInSidebarFromContextualMenu(_:)), feed)
	}

	func markAllAsReadMenuItem(_ feed: Feed) -> NSMenuItem? {
		guard feed.unreadCount > 0 else {
			return nil
		}

		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let menuText = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String

		return menuItem(menuText, #selector(markAllInFeedAsRead(_:)), feed)
	}

	func openInBrowserMenuItem(_ urlString: String) -> NSMenuItem {

		return menuItem(NSLocalizedString("Open in Browser", comment: "Command"), #selector(openInBrowserFromContextualMenu(_:)), urlString)
	}

	func copyArticleURLMenuItem(_ urlString: String) -> NSMenuItem {
		return menuItem(NSLocalizedString("Copy Article URL", comment: "Command"), #selector(copyURLFromContextualMenu(_:)), urlString)
	}

	func copyExternalURLMenuItem(_ urlString: String) -> NSMenuItem {
		return menuItem(NSLocalizedString("Copy External URL", comment: "Command"), #selector(copyURLFromContextualMenu(_:)), urlString)
	}

	func menuItem(_ title: String, _ action: Selector, _ representedObject: Any) -> NSMenuItem {
		let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
		item.representedObject = representedObject
		item.target = self
		return item
	}
}

private final class SharingCommandInfo {
	let service: NSSharingService
	let items: [Any]

	init(service: NSSharingService, items: [Any]) {
		self.service = service
		self.items = items
	}

	func perform() {
		service.perform(withItems: items)
	}
}
