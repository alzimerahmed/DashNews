//
//  ArticleRenderer.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/8/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
#if os(iOS)
import UIKit
#endif
import RSCore
import Articles
import Account

@MainActor struct ArticleRenderer {

	typealias Rendering = (style: String, html: String, title: String, baseURL: String)

	struct Page {
		let url: URL
		let baseURL: URL
		let html: String

		init(name: String) {
			url = Bundle.main.url(forResource: name, withExtension: "html")!
			baseURL = url.deletingLastPathComponent()
			html = try! String(contentsOfFile: url.path, encoding: .utf8)
		}
	}

	static var imageIconScheme = "nnwImageIcon"

	static var blank = Page(name: "blank")
	static var page = Page(name: "page")

	private let article: Article?
	private let extractedArticle: ExtractedArticle?
	private let articleTheme: ArticleTheme
	private let title: String
	private let body: String
	private let baseURL: String?

	private static let longDateTimeFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .long
		formatter.timeStyle = .medium
		return formatter
	}()

	private static let mediumDateTimeFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .short
		return formatter
	}()

	private static let shortDateTimeFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .short
		formatter.timeStyle = .short
		return formatter
	}()

	private static let longDateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .long
		formatter.timeStyle = .none
		return formatter
	}()

	private static let mediumDateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter
	}()

	private static let shortDateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .short
		formatter.timeStyle = .none
		return formatter
	}()

	private static let longTimeFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .long
		return formatter
	}()

	private static let mediumTimeFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .medium
		return formatter
	}()

	private static let shortTimeFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .short
		return formatter
	}()

	private init(article: Article?, extractedArticle: ExtractedArticle?, theme: ArticleTheme) {
		self.article = article
		self.extractedArticle = extractedArticle
		self.articleTheme = theme
		self.title = ArticleStringFormatter.sanitizedTitle(article?.title, forHTML: true) ?? ""
		// Some feeds embed a full HTML document as the article content —
		// render just the body fragment.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/3008>
		if let content = extractedArticle?.content {
			self.body = ArticleRenderingSpecialCases.extractBodyFragmentIfNeeded(content)
			self.baseURL = extractedArticle?.url
		} else {
			self.body = ArticleRenderingSpecialCases.extractBodyFragmentIfNeeded(article?.body ?? "")
			self.baseURL = article?.baseURL?.absoluteString
		}
	}

	// MARK: - API

	static func articleHTML(article: Article, extractedArticle: ExtractedArticle? = nil, theme: ArticleTheme) -> Rendering {
		let renderer = ArticleRenderer(article: article, extractedArticle: extractedArticle, theme: theme)
		return (renderer.articleCSS, renderer.articleHTML, renderer.title, renderer.baseURL ?? "")
	}

	static func multipleSelectionHTML(theme: ArticleTheme) -> Rendering {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, theme: theme)
		return (renderer.articleCSS, renderer.multipleSelectionHTML, renderer.title, renderer.baseURL ?? "")
	}

	static func loadingHTML(theme: ArticleTheme) -> Rendering {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, theme: theme)
		return (renderer.articleCSS, renderer.loadingHTML, renderer.title, renderer.baseURL ?? "")
	}

	static func noSelectionHTML(theme: ArticleTheme) -> Rendering {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, theme: theme)
		return (renderer.articleCSS, renderer.noSelectionHTML, renderer.title, renderer.baseURL ?? "")
	}

	static func noContentHTML(theme: ArticleTheme) -> Rendering {
		let renderer = ArticleRenderer(article: nil, extractedArticle: nil, theme: theme)
		return (renderer.articleCSS, renderer.noContentHTML, renderer.title, renderer.baseURL ?? "")
	}
}

// MARK: - Private

private extension ArticleRenderer {

	private var articleHTML: String {
		return try! MacroProcessor.renderedText(withTemplate: template(), substitutions: articleSubstitutions())
	}

	private var multipleSelectionHTML: String {
		let message = NSLocalizedString("Multiple selection", comment: "Shown in the article view when multiple articles are selected")
		return "<p class='systemMessage'>\(message)</p>"
	}

	private var loadingHTML: String {
		let message = NSLocalizedString("Loading…", comment: "Shown in the article view while an article loads")
		return "<p class='systemMessage'>\(message)</p>"
	}

	private var noSelectionHTML: String {
		let message = NSLocalizedString("No selection", comment: "Shown in the article view when no article is selected")
		return "<p class='systemMessage'>\(message)</p>"
	}

	private var noContentHTML: String {
		return ""
	}

	private var articleCSS: String {
		return try! MacroProcessor.renderedText(withTemplate: styleString(), substitutions: styleSubstitutions())
	}

	static var defaultStyleSheet: String = {
		let path = Bundle.main.path(forResource: "stylesheet", ofType: "css")!
		let s = try! String(contentsOfFile: path, encoding: .utf8)
		return "\n\(s)\n"
	}()

	static let defaultTemplate: String = {
		let path = Bundle.main.path(forResource: "template", ofType: "html")!
		let s = try! String(contentsOfFile: path, encoding: .utf8)
		return s as String
	}()

	/// Highlight styles appended after a custom theme's CSS. Themes replace
	/// the default stylesheet wholesale and don't define the keyword or
	/// key-point marks, so without this the highlights render unstyled.
	static let highlightMarkStyles = """

mark.nnwKeywordHighlight { background-color: rgba(255, 204, 0, 0.45); color: inherit; padding: 0 1px; border-radius: 2px; }
mark.nnwKeyPoint { background-color: rgba(94, 158, 244, 0.28); color: inherit; padding: 0 1px; border-radius: 2px; }
mark a { color: #0645b0; }
@media(prefers-color-scheme: dark) {
	mark.nnwKeywordHighlight { background-color: rgba(255, 204, 0, 0.30); }
	mark.nnwKeyPoint { background-color: rgba(94, 158, 244, 0.40); }
	mark a { color: #9fc5ff; }
}
"""

	func styleString() -> String {
		guard let themeCSS = articleTheme.css else {
			return ArticleRenderer.defaultStyleSheet
		}
		return themeCSS + ArticleRenderer.highlightMarkStyles
	}

	func template() -> String {
		return articleTheme.template ?? ArticleRenderer.defaultTemplate
	}

	func articleSubstitutions() -> [String: String] {
		var d = [String: String]()

		guard let article = article else {
			assertionFailure("Article should have been set before calling this function.")
			return d
		}

		d["title"] = title
		d["preferred_link"] = sanitizedLinkForAttribute(article.preferredURL)

		if let externalURL = article.externalURL, externalURL != article.preferredURL {
			d["external_link_label"] = NSLocalizedString("Link:", comment: "Link")
			d["external_link_stripped"] = externalURL.absoluteString.strippingHTTPOrHTTPSScheme.escapingSpecialXMLCharacters
			d["external_link"] = sanitizedLinkForAttribute(externalURL)
		} else {
			d["external_link_label"] = ""
			d["external_link_stripped"] = ""
			d["external_link"] = ""
		}

		d["body"] = highlightedBody()

		d["text_size_class"] = AppDefaults.shared.articleTextSize.cssClass

		var components = URLComponents()
		components.scheme = Self.imageIconScheme
		components.path = article.articleID
		if let imageIconURLString = components.string {
			d["avatar_src"] = imageIconURLString.escapingSpecialXMLCharacters
		} else {
			d["avatar_src"] = ""
		}

		if self.title.isEmpty {
			d["dateline_style"] = "articleDatelineTitle"
		} else {
			d["dateline_style"] = "articleDateline"
		}

		d["feed_link_title"] = (article.feed?.nameForDisplay ?? "").escapingSpecialXMLCharacters
		d["feed_link"] = sanitizedLinkForAttribute(URL.encodeSpacesIfNeeded(article.feed?.homePageURL))

		d["byline"] = byline()

		let datePublished = article.logicalDatePublished
		d["datetime_long"] = Self.longDateTimeFormatter.string(from: datePublished)
		d["datetime_medium"] = Self.mediumDateTimeFormatter.string(from: datePublished)
		d["datetime_short"] = Self.shortDateTimeFormatter.string(from: datePublished)
		d["date_long"] = Self.longDateFormatter.string(from: datePublished)
		d["date_medium"] = Self.mediumDateFormatter.string(from: datePublished)
		d["date_short"] = Self.shortDateFormatter.string(from: datePublished)
		d["time_long"] = Self.longTimeFormatter.string(from: datePublished)
		d["time_medium"] = Self.mediumTimeFormatter.string(from: datePublished)
		d["time_short"] = Self.shortTimeFormatter.string(from: datePublished)

		return d
	}

	/// Applies the feed's key-point setting (Feature #8) and keyword highlight
	/// rules (Feature #2) to the article body. Key-point marking runs first so
	/// its sentence matching sees pristine text segments.
	func highlightedBody() -> String {
		guard let article else {
			return body
		}
		let feedID = article.feedID
		var result = body
		if FeedIntelligenceStore.shared.highlightKeyPoints(forFeedID: feedID) {
			// In reader view the rendered body comes from the ExtractedArticle,
			// which can differ from the feed text the key sentences were scored
			// on — marks may miss there.
			let keySentences = KeySentenceCache.shared.keySentences(for: article)
			result = KeySentenceHighlighter.highlightedHTML(result, keySentences: keySentences)
		}
		let keywords = KeywordRuleStore.shared.highlightKeywords(forFeedID: feedID)
		if !keywords.isEmpty {
			result = KeywordHighlighter.highlightedHTML(result, keywords: keywords)
		}
		return result
	}

	func byline() -> String {
		guard let authors = article?.authors ?? article?.feed?.authors, !authors.isEmpty else {
			return ""
		}

		// If the author's name is the same as the feed, then we don't want to display it.
		// This code assumes that multiple authors would never match the feed name so that
		// if there feed owner has an article co-author all authors are given the byline.
		if authors.count == 1, let author = authors.first {
			if author.name == article?.feed?.nameForDisplay {
				return ""
			}
		}

		var byline = ""
		var isFirstAuthor = true

		for author in authors {
			if !isFirstAuthor {
				byline += ", "
			}
			isFirstAuthor = false

			var authorEmailAddress: String?
			if let emailAddress = author.emailAddress, !(emailAddress.contains("noreply@") || emailAddress.contains("no-reply@")) {
				authorEmailAddress = emailAddress
			}

			if let emailAddress = authorEmailAddress, emailAddress.contains(" ") {
				byline += emailAddress.escapingSpecialXMLCharacters // probably name plus email address
			} else if let name = author.name, let url = author.url {
				byline += linkedAuthor(name: name, url: url)
			} else if let name = author.name, let emailAddress = authorEmailAddress {
				byline += "\(name.escapingSpecialXMLCharacters) &lt;\(emailAddress.escapingSpecialXMLCharacters)&gt;"
			} else if let name = author.name {
				byline += name.escapingSpecialXMLCharacters
			} else if let emailAddress = authorEmailAddress {
				byline += "&lt;\(emailAddress.escapingSpecialXMLCharacters)&gt;" // TODO: mailto link
			} else if let url = author.url {
				byline += linkedAuthor(name: url, url: url)
			}
		}

		return byline
	}

	/// Untrusted feed/author metadata must never reach the template raw:
	/// MacroProcessor does no escaping, so a feed named `"><script>…`
	/// would otherwise inject markup (and script, when content JS is on)
	/// into the article web view.
	private func linkedAuthor(name: String, url: String) -> String {
		let escapedName = name.escapingSpecialXMLCharacters
		let href = sanitizedLinkForAttribute(URL.encodeSpacesIfNeeded(url))
		guard !href.isEmpty else {
			return escapedName
		}
		return "<a href=\"\(href)\">\(escapedName)</a>"
	}

	/// Returns the URL escaped for an `href` attribute, or "" unless the
	/// scheme is http/https — unparsable or non-web links are dropped
	/// rather than injected into the template.
	private func sanitizedLinkForAttribute(_ url: URL?) -> String {
		guard let url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
			return ""
		}
		return url.absoluteString.escapingSpecialXMLCharacters
	}

	#if os(iOS)
	func styleSubstitutions() -> [String: String] {
		var d = [String: String]()
		let bodyFont = UIFont.preferredFont(forTextStyle: .body)
		d["font-size"] = String(describing: bodyFont.pointSize)
		return d
	}
	#else
	func styleSubstitutions() -> [String: String] {
		return [String: String]()
	}
	#endif

}

// MARK: - Article extension

@MainActor private extension Article {

	var baseURL: URL? {
		var s = link
		if s == nil {
			s = feed?.homePageURL
		}
		if s == nil {
			s = feed?.url
		}

		guard let urlString = s else {
			return nil
		}
		var urlComponents = URLComponents(string: urlString)
		if urlComponents == nil {
			return nil
		}

		// Can’t use url-with-fragment as base URL. The webview won’t load. See scripting.com/rss.xml for example.
		urlComponents!.fragment = nil
		guard let url = urlComponents!.url, url.scheme == "http" || url.scheme == "https" else {
			return nil
		}
		return url
	}
}
