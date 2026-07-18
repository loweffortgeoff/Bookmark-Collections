# Bookmark Collections

Bookmark Collections is a native, local-first bookmark manager for iPhone, iPad, and Mac. It captures links from the iOS Share Sheet, enriches them with webpage metadata, organizes them into one collection plus an independent Favorite state, and mirrors the private library through SwiftData and CloudKit.

The project has no third-party dependencies. Reads and writes use the local SwiftData store first; metadata and CloudKit never sit on the save path.

## Project status

The v1 implementation and simulator/native-Mac automated suites are complete. Distribution remains gated on the real-device CloudKit matrix, CloudKit Production schema deployment, and the final TestFlight/new-account check recorded in [the verification matrix](docs/verification/cloudkit-device-matrix.md).

## Requirements

- Xcode 26.6 or later with Swift 6
- iOS 18 or later
- macOS 15 or later
- An Apple Development team with access to:
  - App Group `group.com.loweffortapps.BookmarkCollections`
  - CloudKit container `iCloud.com.loweffortapps.BookmarkCollections`

The app bundle identifier is `com.loweffortapps.BookmarkCollections`; the extension is `com.loweffortapps.BookmarkCollections.ShareExtension`. Both targets must use the same App Group and CloudKit container.

## Build and test

Open `BookmarkCollections.xcodeproj`, select a development team for both app targets, and build the `BookmarkCollections` scheme.

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'generic/platform=iOS'

xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests

xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsUITests
```

The macOS UI runner must remain code signed. After a clean build, disabling signing can cause XCTest to kill the runner before it bootstraps.

For iOS simulator tests, replace the destination with an installed simulator, such as `platform=iOS Simulator,name=iPhone 17 Pro`, and run the unit and UI targets separately with `-only-testing` for deterministic CI results.

## Architecture

- `BookmarkCollections/Data`: CloudKit-compatible SwiftData models and shared container setup.
- `BookmarkCollections/Domain`: URL normalization, repository mutations, metadata, import/export, and sync health.
- `BookmarkCollections/Features`: adaptive SwiftUI library, editors, Settings, and Recently Deleted.
- `BookmarkCollections/Commands`: focused macOS menu commands and shortcuts.
- `BookmarkShareExtension`: immediate Share Sheet validation and durable App Group save.
- `BookmarkCollectionsTests` and `BookmarkCollectionsUITests`: domain, persistence, accessibility, and cross-platform UI coverage.

On activation, the app reconciles independently created records for the same normalized URL. The earliest-created record remains canonical, Favorite is preserved if either record is favorited, and the most recently modified title and collection win.

## Import and export

Settings supports:

- UTF-8 text import with one URL per line.
- Versioned JSON backup and restore, preserving UUIDs, titles, collections/order, favorites, and dates.
- Netscape-compatible HTML export for browser portability.

Preview and favicon binaries are deliberately omitted from JSON backups and are fetched again after restore.

## Data and privacy

The full library remains available locally. CloudKit uses the user’s private database; the app includes no analytics, telemetry, custom account, or third-party sync service. Settings reports only iCloud account availability and does not claim an exact or complete sync time.

See [DECISIONS.md](DECISIONS.md) for the design rationale and [CHANGELOG.md](CHANGELOG.md) for release contents.
