//
//  KeySentenceCache.swift
//  DashNews
//
//  Created by DashNews on 10/2/26.
//  Copyright © 2026 Alzimer Ahmed. All rights reserved.
//

import Foundation
import Articles

/// Caches ExtractiveSummarizer key sentences so article re-renders — theme
/// changes, text-size changes, extractor transitions — don't re-run the
/// NLTagger scoring pipeline on the main thread. Feature #8.
///
/// Keys combine the article ID with hashes of the text and title the scoring
/// ran on, so a feed refresh that changes an article's content produces a
/// fresh entry. Cleared whenever FeedIntelligenceStore saves new settings.
/// NSCache is thread-safe, so the unchecked Sendable is sound.
nonisolated final class KeySentenceCache: @unchecked Sendable {

	static let shared = KeySentenceCache()

	private let cache = NSCache<NSString, NSArray>()

	private init() {
		cache.countLimit = 100
	}

	func keySentences(for article: Article, maxCount: Int = ExtractiveSummarizer.defaultMaxSentenceCount) -> [String] {
		let text = article.summarizableText
		let key = "\(article.articleID)#\((article.title ?? "").hashValue)#\(text.hashValue)" as NSString
		if let cached = cache.object(forKey: key) as? [String] {
			return cached
		}
		let sentences = ExtractiveSummarizer().keySentences(in: text, title: article.title, maxCount: maxCount)
		cache.setObject(sentences as NSArray, forKey: key)
		return sentences
	}

	func removeAll() {
		cache.removeAllObjects()
	}
}
