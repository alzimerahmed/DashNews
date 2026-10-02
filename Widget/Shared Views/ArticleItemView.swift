//
//  ArticleItemView.swift
//  NetNewsWire Widget Extension
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSWeb

struct ArticleItemView: View {

	var article: LatestArticle
	var deepLink: URL
	@State private var iconImage: Image?

	var body: some View {
		Link(destination: deepLink, label: {
			HStack(alignment: .top, spacing: nil, content: {
				// Feed Icon
				if let iconImage {
					iconImage
						.resizable()
						.frame(width: WidgetLayout.feedIconSize, height: WidgetLayout.feedIconSize)
						.cornerRadius(4)
						.accessibilityHidden(true)
				}

				// Title and Feed Name
				VStack(alignment: .leading) {
					Text(article.articleTitle ?? String(localized: "label.text.untitled-article", comment: "Shown in place of a missing article title"))
						.font(.footnote)
						.bold()
						.lineLimit(1)
						.foregroundColor(.primary)
						.padding(.top, -3)

					HStack {
						Text(article.feedTitle)
							.font(.caption)
							.lineLimit(1)
							.foregroundColor(.secondary)
						Spacer()
						Text(pubDate(article.pubDate))
							.font(.caption)
							.lineLimit(1)
							.foregroundColor(.secondary)
					}
				}
			})
			.accessibilityElement(children: .combine)
		}).onAppear {
			iconImage = thumbnail(from: article.feedIconPath)
		}
	}

	func thumbnail(from path: String?) -> Image? {
		guard let imagePath = path else {
			return fallbackIcon
		}

		let url = URL(fileURLWithPath: imagePath)

		guard let data = try? Data(contentsOf: url),
			  let uiImage = UIImage(data: data) else {
			return fallbackIcon
		}

		return Image(uiImage: uiImage)
	}

	private var fallbackIcon: Image {
		Image(uiImage: UIImage(systemName: "globe") ?? UIImage())
	}

	func pubDate(_ dateString: String) -> String {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
		guard let date = dateFormatter.date(from: dateString) else {
			return ""
		}

		let displayFormatter = DateFormatter()
		displayFormatter.dateStyle = .medium
		displayFormatter.timeStyle = .none

		return displayFormatter.string(from: date)
	}
}
