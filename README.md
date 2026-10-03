<div align="center">

<img src="Technotes/Images/icon_1024.png" alt="DashNews icon" height="128" width="128">

# DashNews

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS-black.svg?logo=apple)](#building)
[![Language](https://img.shields.io/badge/language-Swift-orange.svg?logo=swift)](https://github.com/alzimerahmed/DashNews)
[![CI](https://img.shields.io/github/actions/workflow/status/alzimerahmed/DashNews/ci.yml?branch=main&label=CI)](https://github.com/alzimerahmed/DashNews/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/alzimerahmed/DashNews?label=release)](https://github.com/alzimerahmed/DashNews/releases)

*A free and open-source feed reader for macOS and iOS — local-first, private, with on-device intelligence.*

[Features](#features) • [Building](#building) • [Usage](#usage) • [License](#license)

</div>

---

## Features

**Reading**
- RSS, Atom, JSON Feed, and RSS-in-JSON.
- Local-first: articles live on device in SQLite — no account required.
- Native macOS and iOS apps with sidebar navigation and smart feeds (Today, All Unread, Starred).
- Reader view and full-content article extraction.
- Article themes (`.nnwtheme`), including the Hyperlegible pack.

**Intelligence** (all on-device, no cloud)
- Article summaries via Apple Foundation Models, with a deterministic extractive fallback.
- Per-feed keyword rules — hide matching articles, highlight keywords in the article body.
- Key-point highlighting inside articles.
- Full-text search (SQLite FTS5) and saved searches that persist as smart feeds.
- Article translation via the system translator.

**Sync & utility**
- Optional sync accounts: CloudKit, NewsBlur, Feedbin, Feedly, and any Google-Reader-compatible API.
- iCloud read/starred status sync for local (On My Mac/iPhone) accounts.
- Home-screen and lock-screen widgets.
- Mark-as-read on scroll; Send to Instapaper.
- Full English + Spanish localization.
- Keyboard-first on Mac, with full menu commands and AppleScript support.
- Private by design: no analytics, no tracking, no ads.

DashNews is a fork of [NetNewsWire](https://github.com/Ranchero-Software/NetNewsWire) by Brent Simmons and contributors, rebranded and continued by Alzimer Ahmed.

## Building

Requires a Mac with Xcode 26.3.

```bash
git clone https://github.com/alzimerahmed/DashNews.git
cd "DashNews - News Feed app"   # or the directory you cloned into
```

Open `DashNews.xcodeproj` and build the `DashNews` (macOS) or `DashNews-iOS` scheme. No paid developer account needed — the no-signing xcconfigs in `.github/` show how CI builds without credentials.

All pushes and pull requests run CI: SwiftLint (strict), the macOS test plan, and the iOS simulator test plan. Release tags (`mac-*`, `iOS-*`, `v*`) trigger `.github/workflows/release.yml`, which builds and attaches the artifacts to a GitHub release.

## Usage

Add a feed with **File → New Feed** (⌘N), paste a feed or site URL. Choose **On Disk** to keep everything local, or sign into a sync account in **Settings → Accounts**.

## FAQ

**Why do parts of the code still mention NetNewsWire?**
DashNews is a fork of NetNewsWire. The app identity, targets, and bundle IDs are DashNews; upstream attribution remains in file headers and credits, as required by the MIT license.

**Can I use my existing NetNewsWire feeds?**
Yes — export an OPML file from any reader and import it in DashNews.

## Contributing

Fork the repository, create a branch, and open a pull request. Keep changes focused; CI must pass (SwiftLint strict, macOS and iOS tests).

## Changelog

See [Releases](https://github.com/alzimerahmed/DashNews/releases) and `Technotes/ReleaseNotes-*.markdown`.

## License

Copyright © 2026 Alzimer Ahmed.

DashNews is free software under the [MIT License](LICENSE). It includes code from NetNewsWire, © 2002–2025 Brent Simmons and contributors, under the same license.
