# Tucked

Tucked is a native, local-first bookmark manager for iPhone, iPad, and Mac. It captures links, text links, images, and screenshots from the iOS Share Sheet and macOS Share menus, holds text snippets created directly in Tucked, enriches links with webpage metadata, organizes every item into zero or one collection plus an independent Favorite state, and mirrors the private library through SwiftData and CloudKit. Links and images can be captured on both platforms; Images/Links/Snippets sidebar filters, a full-screen zoomable image viewer, and a Get Info panel on the bookmark context menu keep the mixed library browsable. A Forgotten sidebar destination surfaces never-opened items older than 30 days, and Surprise me opens a random item from the current visible set.

On Mac, **Save to Tucked** is a capture-first action: it saves immediately
with no collection and Favorite off, then dismisses. Collection and Favorite
can be changed later in Tucked. The iPhone and iPad Share Sheet keeps its
interactive Collection and Favorite controls.

The Xcode project, bundle identifier, and internal file/folder names still use `BookmarkCollections` (see Requirements and Architecture below) — that rename is a separate, not-yet-scheduled task.

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

To install the Mac app rather than just build it, run `scripts/install-mac.sh`.
It installs to `/Applications/Tucked.app` and launches from there, so the app
survives a rebuild and appears in Spotlight. Building alone leaves the only copy
in `build/DerivedData`, where the next build or test run replaces it. Defaults to
`Debug` (Development CloudKit environment, matching the device installs); set
`CONFIGURATION=Release` once the Production schema is deployed.
`scripts/install-all-devices.sh` calls this script for its Mac step.

The macOS UI runner must remain code signed. After a clean build, disabling signing can cause XCTest to kill the runner before it bootstraps. If the macOS UI suite starts failing wholesale — element queries timing out even on known-good code — the runner's signature has gone stale; run `scripts/reset-ui-tests.sh` to clear DerivedData and rerun the suite from a clean rebuild.

For iOS simulator tests, replace the destination with an installed simulator, such as `platform=iOS Simulator,name=iPhone 17 Pro`, and run the unit and UI targets separately with `-only-testing` for deterministic CI results.

## Architecture

- `BookmarkCollections/Data`: CloudKit-compatible SwiftData models and shared container setup.
- `BookmarkCollections/Domain`: URL normalization, repository mutations, metadata, import/export, sync health, and shared image downsampling (`ImageDownsampler`, used by both the app and the share extension).
- `BookmarkCollections/Features`: adaptive SwiftUI library, editors, Settings, and Recently Deleted.
- `BookmarkCollections/Commands`: focused macOS menu commands and shortcuts.
- `BookmarkShareExtension`: immediate Share validation and durable App Group
  save, using Quick Save on macOS and an interactive confirmation form on iOS.
- `BookmarkCollectionsTests` and `BookmarkCollectionsUITests`: domain, persistence, accessibility, and cross-platform UI coverage.

On activation, the app reconciles independently created records for the same normalized URL. The earliest-created record remains canonical, Favorite is preserved if either record is favorited, and the most recently modified title and collection win.

## Import and export

Settings supports:

- UTF-8 text import with one URL per line.
- Versioned JSON backup and restore, preserving UUIDs, titles, collections/order, favorites, dates, and text snippets.
- Netscape-compatible HTML export for browser portability.

Preview and favicon binaries are deliberately omitted from JSON backups and are fetched again after restore.

Update every device to a build that knows the `text` kind before any snippet
reaches the library. Snippets arrive by two routes: you create them in Tucked,
or you restore them from a backup. An older build reads an unknown kind as a
link. Its reconciliation runs on activation, treats every synced snippet as a
duplicate of every other one, and deletes all but the oldest.

## Data and privacy

The full library remains available locally. CloudKit uses the user’s private database; the app includes no analytics, telemetry, custom account, or third-party sync service. Settings reports only iCloud account availability and does not claim an exact or complete sync time.

See [DECISIONS.md](DECISIONS.md) for the design rationale and [CHANGELOG.md](CHANGELOG.md) for release contents.
