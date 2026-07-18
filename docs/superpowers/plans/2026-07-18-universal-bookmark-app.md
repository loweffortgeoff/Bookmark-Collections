# Universal Bookmark App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native universal bookmark manager for iPhone, iPad, and Mac with fast Share Sheet capture, a visual library, collections, favorites, local-first storage, CloudKit sync, and portable backups.

**Architecture:** A SwiftUI app and Share Extension share a SwiftData store through an App Group. Focused services handle URL normalization, bookmark mutations, metadata enrichment, import/export, and sync health; views consume those services through environment dependencies and SwiftData queries. CloudKit mirrors the private local store but never sits on the critical path for saving or opening a bookmark.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, CloudKit, LinkPresentation, UniformTypeIdentifiers, XCTest, Xcode 27; no third-party dependencies.

## Global Constraints

- Targets: iOS/iPadOS 18.0 or later and macOS 15.0 or later.
- Bundle identifier: `com.loweffortapps.BookmarkCollections` while the product name remains provisional.
- App Group: `group.com.loweffortapps.BookmarkCollections`.
- CloudKit container: `iCloud.com.loweffortapps.BookmarkCollections` using the private database.
- Store links only; no tags, image library, webpage archive, collaboration, accounts, custom server, analytics, browser extension, StoreKit, or third-party package.
- A local save must complete before metadata fetching or CloudKit synchronization.
- A bookmark belongs to zero or one collection; Favorites is an independent flag.
- Use SwiftUI and native system components, SF Symbols, system fonts, semantic colors, Dynamic Type, VoiceOver, and light/dark appearances.
- Destructive confirmation is required only for deleting a collection, permanently deleting bookmarks, and emptying Recently Deleted.
- Do not use the word “instantly” in UI copy.

## Planned file structure

```text
BookmarkCollections.xcodeproj/
BookmarkCollections/
  BookmarkCollectionsApp.swift       App entry point and shared container injection
  BookmarkCollections.entitlements   App Group and CloudKit capabilities
  Data/
    Bookmark.swift                    SwiftData bookmark model and metadata state
    BookmarkCollection.swift          SwiftData collection model
    ModelContainerFactory.swift       Shared local/CloudKit container construction
  Domain/
    NormalizedURL.swift               URL validation and canonical comparison
    BookmarkRepository.swift          Save, update, deduplicate, reconcile, delete
    CollectionRepository.swift        Collection lifecycle and ordering
    BookmarkSort.swift                Supported sort descriptors
    MetadataProvider.swift            LinkPresentation adapter
    MetadataEnricher.swift            Pending-preview orchestration
    LibraryImportService.swift        Text and JSON import
    LibraryExportService.swift        HTML and JSON export
    BackupDocument.swift              Codable lossless user-data representation
    SyncHealthMonitor.swift            iCloud account availability and observable failures
  Features/
    Library/LibraryRootView.swift      Adaptive navigation shell
    Library/LibraryGridView.swift      Responsive bookmark grid and empty state
    Library/BookmarkCard.swift         Visual card and accessibility description
    Library/LibraryDestination.swift   All/Favorites/collection/deleted routing
    Library/LibraryToolbar.swift       Add, sort, search, and selection actions
    Bookmark/BookmarkEditorView.swift  Title, collection, favorite editing
    Bookmark/AddBookmarkView.swift     Manual URL capture
    Bookmark/BookmarkActions.swift     Context-menu actions
    Collections/CollectionListView.swift
    Collections/CollectionEditor.swift
    Deleted/RecentlyDeletedView.swift
    Settings/SettingsView.swift
    Settings/ImportSummaryView.swift
  Commands/BookmarkCommands.swift     Mac menu commands and shortcuts
BookmarkShareExtension/
  ShareViewController.swift           Extension host bridge
  ShareCaptureView.swift              Native save UI
  ShareCaptureModel.swift             URL loading and local save state
  BookmarkShareExtension.entitlements
BookmarkCollectionsTests/
  ModelContainerTests.swift
  NormalizedURLTests.swift
  BookmarkRepositoryTests.swift
  CollectionRepositoryTests.swift
  MetadataEnricherTests.swift
  ImportExportTests.swift
  LibraryFilteringTests.swift
  RecentlyDeletedTests.swift
  ShareCaptureModelTests.swift
BookmarkCollectionsUITests/
  BookmarkCollectionsUITests.swift
docs/verification/cloudkit-device-matrix.md
```

---

### Task 1: Scaffold the universal app and test harness

**Files:**
- Create: `BookmarkCollections.xcodeproj/project.pbxproj`
- Create: `BookmarkCollections/BookmarkCollectionsApp.swift`
- Create: `BookmarkCollections/BookmarkCollections.entitlements`
- Create: `BookmarkCollectionsTests/ModelContainerTests.swift`
- Create: `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift`

**Interfaces:**
- Produces: the `BookmarkCollections` app scheme, unit-test target, UI-test target, signing capabilities, and `ModelContainerFactory.make(inMemory:cloudKit:)` seam used by later tasks.

- [ ] **Step 1: Create the Xcode project and targets**

  In Xcode, create a Multiplatform App named `BookmarkCollections`, organization identifier `com.loweffortapps`, SwiftUI interface, Swift language, and both unit/UI tests. Set iOS deployment to 18.0 and macOS deployment to 15.0. Add iCloud/CloudKit and App Groups capabilities to the app; select the identifiers in Global Constraints. Do not enable automatic model generation from the template.

- [ ] **Step 2: Add a failing container smoke test**

```swift
import SwiftData
import XCTest
@testable import BookmarkCollections

final class ModelContainerTests: XCTestCase {
    func testInMemoryContainerCanBeCreated() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        XCTAssertNotNil(container.mainContext.container)
    }
}
```

- [ ] **Step 3: Run the test and verify the missing factory failure**

  Run: `xcodebuild test -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/ModelContainerTests`

  Expected: FAIL with `Cannot find 'ModelContainerFactory' in scope`.

- [ ] **Step 4: Add the app entry point and temporary factory seam**

```swift
import SwiftData
import SwiftUI

@main
struct BookmarkCollectionsApp: App {
    private let container = try! ModelContainerFactory.make(inMemory: false, cloudKit: true)

    var body: some Scene {
        WindowGroup { Text("Bookmarks") }
            .modelContainer(container)
    }
}

enum ModelContainerFactory {
    static func make(inMemory: Bool, cloudKit: Bool) throws -> ModelContainer {
        let schema = Schema([ScaffoldRecord.self])
        let configuration = ModelConfiguration(
            "BookmarkCollectionsScaffold",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit ? .automatic : .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

@Model
final class ScaffoldRecord {
    var createdAt = Date()
    init() {}
}
```

- [ ] **Step 5: Build every destination and run smoke tests**

  Run macOS tests as in Step 3, then run `xcodebuild build -scheme BookmarkCollections -destination 'generic/platform=iOS Simulator'`.

  Expected: both commands succeed; the macOS app opens to “Bookmarks.”

- [ ] **Step 6: Commit the scaffold**

```bash
git add BookmarkCollections.xcodeproj BookmarkCollections BookmarkCollectionsTests BookmarkCollectionsUITests
git commit -m "chore: scaffold universal bookmark app"
```

### Task 2: Add the CloudKit-compatible persistence model

**Files:**
- Create: `BookmarkCollections/Data/Bookmark.swift`
- Create: `BookmarkCollections/Data/BookmarkCollection.swift`
- Create: `BookmarkCollections/Data/ModelContainerFactory.swift`
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift`
- Modify: `BookmarkCollectionsTests/ModelContainerTests.swift`

**Interfaces:**
- Produces: `Bookmark`, `BookmarkCollection`, `Bookmark.MetadataState`, and `ModelContainerFactory.make(inMemory:cloudKit:)`.
- Invariant: every persisted property has a default or is optional; preview binaries use external storage; relationships are optional for CloudKit compatibility.

- [ ] **Step 1: Replace the smoke test with schema round-trip tests**

```swift
func testBookmarkRoundTripPreservesOrganization() throws {
    let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
    let collection = BookmarkCollection(name: "Development", sortPosition: 0)
    let bookmark = Bookmark(urlString: "https://example.com", normalizedURLString: "https://example.com/")
    bookmark.title = "Example"
    bookmark.isFavorite = true
    bookmark.collection = collection
    container.mainContext.insert(collection)
    container.mainContext.insert(bookmark)
    try container.mainContext.save()

    let saved = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Bookmark>()).first)
    XCTAssertEqual(saved.title, "Example")
    XCTAssertEqual(saved.collection?.name, "Development")
    XCTAssertTrue(saved.isFavorite)
}
```

- [ ] **Step 2: Run and confirm compilation fails for missing models**

  Run the ModelContainerTests command from Task 1. Expected: FAIL because `Bookmark` and `BookmarkCollection` are undefined.

- [ ] **Step 3: Implement focused models**

  Define `@Model final class Bookmark` with the exact fields from the design: `id`, `urlString`, `normalizedURLString`, `title`, `domain`, external-storage `faviconData` and `previewImageData`, `isFavorite`, optional `collection`, `createdAt`, `modifiedAt`, optional `deletedAt`, `metadataStateRawValue`, and optional `lastMetadataRefreshAt`. Define `MetadataState: String, Codable, CaseIterable` with `pending`, `ready`, and `failed`, exposed through a non-persisted computed `metadataState`.

  Define `@Model final class BookmarkCollection` with `id`, `name`, `sortPosition`, `createdAt`, `modifiedAt`, and an optional inverse `[Bookmark]?`. Initializers must supply defaults exactly matching CloudKit optionality.

- [ ] **Step 4: Move and complete the container factory**

```swift
enum ModelContainerFactory {
    static let appGroupIdentifier = "group.com.loweffortapps.BookmarkCollections"

    static func make(inMemory: Bool, cloudKit: Bool) throws -> ModelContainer {
        let schema = Schema([Bookmark.self, BookmarkCollection.self])
        let configuration = ModelConfiguration(
            "BookmarkCollections",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: inMemory ? .automatic : .identifier(appGroupIdentifier),
            cloudKitDatabase: cloudKit ? .automatic : .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
```

- [ ] **Step 5: Run schema tests and inspect the generated CloudKit schema in Development**

  Expected: unit tests PASS; a signed development launch creates the local store without a model compatibility exception.

- [ ] **Step 6: Commit the model**

```bash
git add BookmarkCollections/Data BookmarkCollections/BookmarkCollectionsApp.swift BookmarkCollectionsTests/ModelContainerTests.swift
git commit -m "feat: add bookmark persistence model"
```

### Task 3: Validate, normalize, save, and reconcile URLs

**Files:**
- Create: `BookmarkCollections/Domain/NormalizedURL.swift`
- Create: `BookmarkCollections/Domain/BookmarkRepository.swift`
- Create: `BookmarkCollectionsTests/NormalizedURLTests.swift`
- Create: `BookmarkCollectionsTests/BookmarkRepositoryTests.swift`

**Interfaces:**
- Produces: `NormalizedURL.init(_:) throws`, `BookmarkRepository.save(url:collection:favorite:)`, `BookmarkRepository.reconcileDuplicates()`, and `SaveResult`.
- `SaveResult` cases: `.created(Bookmark)`, `.updated(Bookmark)`, `.restored(Bookmark)`.

- [ ] **Step 1: Write table-driven normalization tests**

```swift
func testNormalizationRules() throws {
    let cases = [
        ("HTTPS://Example.COM:443", "https://example.com/"),
        ("https://example.com/a#section", "https://example.com/a"),
        ("https://example.com/a?utm_source=x&id=7", "https://example.com/a?id=7"),
        ("https://example.com/a?fbclid=x&gclid=y", "https://example.com/a")
    ]
    for (input, expected) in cases {
        XCTAssertEqual(try NormalizedURL(input).string, expected)
    }
}

func testRejectsUnsupportedSchemes() {
    XCTAssertThrowsError(try NormalizedURL("file:///tmp/a"))
    XCTAssertThrowsError(try NormalizedURL("not a url"))
}
```

- [ ] **Step 2: Run tests and verify `NormalizedURL` is missing**

  Expected: compilation FAIL.

- [ ] **Step 3: Implement normalization**

  Use `URLComponents`, require an `http` or `https` scheme and nonempty host, lowercase scheme/host, remove fragments/default ports, set an empty path to `/`, and filter query items whose lowercase name has prefix `utm_` or equals `fbclid`/`gclid`. Preserve the relative order and values of all other query items. Expose the validated original `URL` and canonical `string`.

- [ ] **Step 4: Write repository tests for create, duplicate update, restore, and offline collision reconciliation**

  Tests must assert: a new URL creates `metadataState == .pending`; the same normalized URL reuses the existing UUID; a deleted match is restored; and two inserted records with the same normalized URL reconcile to the earliest-created record while OR-ing favorite and taking title/collection from the most recently modified record.

- [ ] **Step 5: Implement `BookmarkRepository` as an `@MainActor` value around `ModelContext`**

  `save` must normalize first, fetch active and deleted matches, update `modifiedAt`, and save exactly once. `reconcileDuplicates` must group fetched bookmarks by normalized URL and apply the merge policy from the design. Do not use SwiftData uniqueness constraints.

- [ ] **Step 6: Run both suites and commit**

```bash
xcodebuild test -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/NormalizedURLTests -only-testing:BookmarkCollectionsTests/BookmarkRepositoryTests
git add BookmarkCollections/Domain BookmarkCollectionsTests
git commit -m "feat: add reliable bookmark saving"
```

### Task 4: Add collections, favorites, deletion, filtering, and sorting

**Files:**
- Create: `BookmarkCollections/Domain/CollectionRepository.swift`
- Create: `BookmarkCollections/Domain/BookmarkSort.swift`
- Create: `BookmarkCollections/Features/Library/LibraryDestination.swift`
- Create: `BookmarkCollectionsTests/CollectionRepositoryTests.swift`
- Create: `BookmarkCollectionsTests/RecentlyDeletedTests.swift`
- Create: `BookmarkCollectionsTests/LibraryFilteringTests.swift`
- Modify: `BookmarkCollections/Domain/BookmarkRepository.swift`

**Interfaces:**
- Produces collection CRUD/reorder, `setFavorite`, `move`, `softDelete`, `restore`, `permanentlyDelete`, `purgeExpiredDeleted(now:)`, `LibraryDestination`, and `BookmarkSort` descriptors.

- [ ] **Step 1: Write behavior tests**

  Cover collection create/rename/reorder; collection deletion leaving bookmarks unfiled; favorite state surviving a collection move; soft deletion visibility; restore; confirmation-independent repository permanent deletion; and purging only records whose `deletedAt` is more than 30 days old.

- [ ] **Step 2: Write filtering and sorting tests**

  Build an in-memory fixture and verify All Items excludes deleted records, Favorites requires `isFavorite`, a collection destination matches its UUID, Recently Deleted includes only deleted records, search matches title/domain/URL/collection name case-insensitively, and every sort mode has a stable UUID tie-breaker.

- [ ] **Step 3: Run the focused tests and confirm missing APIs**

  Expected: compilation FAIL naming the repository and destination members.

- [ ] **Step 4: Implement repositories and descriptors**

  Keep mutations on `@MainActor`, update `modifiedAt` on every user-visible change, normalize sort positions after reorder/delete, and save once per operation. `BookmarkSort` cases are `dateAdded`, `dateModified`, `title`, and `domain`; each returns ascending/descending `SortDescriptor<Bookmark>` arrays plus a stable `id` descriptor.

- [ ] **Step 5: Run tests and commit**

```bash
xcodebuild test -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/CollectionRepositoryTests -only-testing:BookmarkCollectionsTests/RecentlyDeletedTests -only-testing:BookmarkCollectionsTests/LibraryFilteringTests
git add BookmarkCollections/Domain BookmarkCollections/Features/Library BookmarkCollectionsTests
git commit -m "feat: add library organization rules"
```

### Task 5: Enrich saved URLs without risking the save

**Files:**
- Create: `BookmarkCollections/Domain/MetadataProvider.swift`
- Create: `BookmarkCollections/Domain/MetadataEnricher.swift`
- Create: `BookmarkCollectionsTests/MetadataEnricherTests.swift`
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift`

**Interfaces:**
- Produces `LinkMetadata { title, domain, faviconData, previewImageData }`, protocol `MetadataProviding`, actor `LinkPresentationMetadataProvider`, and `@MainActor MetadataEnricher.enrichPending(limit:)`/`refresh(_:)`.

- [ ] **Step 1: Write tests with a fake provider**

```swift
struct StubMetadataProvider: MetadataProviding {
    let result: Result<LinkMetadata, Error>
    func metadata(for url: URL) async throws -> LinkMetadata { try result.get() }
}
```

  Assert success stores title/domain/artwork and `.ready`; failure preserves the URL, sets `.failed`, and saves; retry can transition failed to ready; pending enrichment respects its limit.

- [ ] **Step 2: Run tests and verify missing metadata types**

  Expected: compilation FAIL.

- [ ] **Step 3: Implement the Link Presentation adapter**

  Wrap `LPMetadataProvider.startFetchingMetadata(for:)`. Extract `title`, host/domain, and image/icon provider data using `NSItemProvider.loadDataRepresentation` for supported image UTTypes. Downsample oversized artwork before persistence so neither dimension exceeds 1200 pixels. Treat absent artwork as valid metadata, not a failure.

- [ ] **Step 4: Implement pending enrichment orchestration**

  Fetch bookmarks in `.pending`, process at most the passed limit, and update each record independently. Call `enrichPending(limit: 20)` from an app-scene active task. Never call metadata enrichment inside `BookmarkRepository.save`.

- [ ] **Step 5: Run tests and commit**

```bash
xcodebuild test -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/MetadataEnricherTests
git add BookmarkCollections/Domain BookmarkCollections/BookmarkCollectionsApp.swift BookmarkCollectionsTests/MetadataEnricherTests.swift
git commit -m "feat: enrich bookmark previews"
```

### Task 6: Implement portable import and export

**Files:**
- Create: `BookmarkCollections/Domain/BackupDocument.swift`
- Create: `BookmarkCollections/Domain/LibraryImportService.swift`
- Create: `BookmarkCollections/Domain/LibraryExportService.swift`
- Create: `BookmarkCollectionsTests/ImportExportTests.swift`

**Interfaces:**
- Produces `ImportSummary(newCount:duplicateCount:restoredCount:failedLines:)`, `importText(_:)`, `importJSON(_:)`, `exportJSON()`, and `exportHTML()`.

- [ ] **Step 1: Write round-trip and accounting tests**

  Verify text import ignores blank lines and counts valid, duplicate, restored, and invalid entries. Verify JSON round-trip preserves UUIDs, URLs, user-edited titles, collection membership/order, favorites, and dates. Verify HTML escapes titles/URLs and produces Netscape bookmark format. Verify preview/favicon bytes are absent from JSON.

- [ ] **Step 2: Run and confirm missing services**

  Expected: compilation FAIL.

- [ ] **Step 3: Implement the Codable backup schema**

  Use a versioned root `BackupDocument(version: 1, exportedAt:, collections:, bookmarks:)`. Define nested Codable value types containing every user-authored field and organizational date required by the design. Reject unsupported future versions with a typed error.

- [ ] **Step 4: Implement imports through repository rules**

  Text import splits on newlines and passes each nonblank line through `BookmarkRepository.save`. JSON import creates/updates collections by stable UUID, then bookmarks by stable UUID, normalizes URLs, reconciles duplicates, and marks missing previews pending.

- [ ] **Step 5: Implement atomic export payload generation**

  Return `Data` for JSON and HTML so the Settings layer can write through `FileDocument`/`fileExporter`. JSON uses sorted keys and ISO-8601 dates. HTML includes collection folders, an Unfiled section, and Favorites as `TAGS="favorite"` without duplicating links.

- [ ] **Step 6: Run tests and commit**

```bash
xcodebuild test -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/ImportExportTests
git add BookmarkCollections/Domain BookmarkCollectionsTests/ImportExportTests.swift
git commit -m "feat: add portable library backups"
```

### Task 7: Build the adaptive visual library and editing flows

**Files:**
- Create: every file under `BookmarkCollections/Features/Library`, `BookmarkCollections/Features/Bookmark`, `BookmarkCollections/Features/Collections`, and `BookmarkCollections/Features/Deleted` listed in Planned file structure
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift`
- Modify: `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift`

**Interfaces:**
- Consumes: repositories, destinations, sorts, and metadata enrichment from Tasks 3–5.
- Produces: the complete in-app browse, search, add, edit, collection, favorite, and recovery experience.

- [ ] **Step 1: Add UI launch arguments and failing navigation tests**

  Add an in-memory seeded-container launch path when UI tests pass `-ui-testing`. Write UI tests that assert All Items, Favorites, Collections, and Recently Deleted are reachable; a seeded card opens its editor from the context menu; and permanent deletion presents confirmation.

- [ ] **Step 2: Run the UI tests and verify the scaffold app fails them**

  Run: `xcodebuild test -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsUITests`

  Expected: FAIL because library accessibility identifiers do not exist.

- [ ] **Step 3: Build `LibraryRootView` with native adaptive navigation**

  Use `NavigationSplitView` for regular-width iPad/Mac and native compact navigation for iPhone. Keep destination selection as `LibraryDestination?`. Provide `.searchable`, toolbar add/sort actions, and navigation to settings. Do not create a custom sidebar container.

- [ ] **Step 4: Build the responsive grid and card**

  Use `LazyVGrid` with adaptive minimum card widths appropriate to each platform. Card content is preview artwork, title, and domain using semantic colors and relative typography. The fallback combines the site initial/domain with an SF Symbol. The whole card is the link; no tiny overlay controls.

- [ ] **Step 5: Add native actions and editor sheets**

  Implement context menus and supported swipe actions for Favorite, Move, Edit, Share, Refresh Preview, and Delete. Build native forms for manual URL entry, bookmark editing, collection create/rename, and collection deletion confirmation. Collection deletion leaves bookmarks unfiled.

- [ ] **Step 6: Add drag-and-drop and multi-selection**

  Accept `public.url` drops in the library on iPad and Mac and route every valid item through `BookmarkRepository.save`. Use native selection to move, favorite/unfavorite, share, or delete multiple bookmarks where the platform supports it; disable actions that have no valid selection.

- [ ] **Step 7: Add Recently Deleted and useful empty states**

  Delete without confirmation into Recently Deleted. Restore directly. Confirm permanent delete and Empty Recently Deleted. Empty states offer Add Link/Create Collection or explain that deleted bookmarks remain recoverable for 30 days.

- [ ] **Step 8: Run unit/UI tests on macOS and iPhone Simulator**

  Expected: existing unit tests pass; UI navigation/actions pass on macOS and an available iPhone simulator; manual appearance check shows no clipped cards at accessibility text sizes.

- [ ] **Step 9: Commit the main experience**

```bash
git add BookmarkCollections/Features BookmarkCollections/BookmarkCollectionsApp.swift BookmarkCollectionsUITests
git commit -m "feat: build visual bookmark library"
```

### Task 8: Add the Share Extension as the primary capture path

**Files:**
- Create: `BookmarkShareExtension/ShareViewController.swift`
- Create: `BookmarkShareExtension/ShareCaptureView.swift`
- Create: `BookmarkShareExtension/ShareCaptureModel.swift`
- Create: `BookmarkShareExtension/BookmarkShareExtension.entitlements`
- Create: `BookmarkCollectionsTests/ShareCaptureModelTests.swift`
- Modify: `BookmarkCollections.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `@MainActor ShareCaptureModel.load(from:)`, `save(collectionID:favorite:)`, and `ShareCaptureState`.
- Consumes: shared container factory, URL normalizer, and bookmark repository.

- [ ] **Step 1: Add the Share Extension target and capabilities**

  Add an iOS Share Extension embedded in the app with bundle identifier `com.loweffortapps.BookmarkCollections.ShareExtension`. Add the same App Group and CloudKit container entitlements. Set activation rules to one web URL or one plain-text item and reject unrelated attachments.

- [ ] **Step 2: Write model tests**

  Use fake extension input providers. Assert a URL attachment loads; plain text containing one valid URL loads; unsupported input reports a useful error; Save succeeds against an in-memory store before metadata completes; an App Group/store error does not call completion; and a duplicate returns update/restore behavior.

- [ ] **Step 3: Run tests and verify missing capture model**

  Expected: compilation FAIL.

- [ ] **Step 4: Implement the model and SwiftUI share view**

  Load the first supported URL, begin metadata fetching concurrently, and immediately enable Save after validation. Show URL, available title/preview, collection picker, and Favorite toggle in a native form. On Save, persist through `BookmarkRepository`, then call the extension completion handler. Do not wait for metadata or CloudKit.

- [ ] **Step 5: Bridge the extension host**

  `ShareViewController` owns the shared container and embeds `ShareCaptureView` in `UIHostingController`. Cancellation calls `cancelRequest`; store failure remains visible with Retry/Cancel.

- [ ] **Step 6: Test from Safari on iPhone and iPad simulators**

  Share a web page, select a collection, save, launch the main app, and verify the bookmark appears. Repeat while network is disabled using a plain URL copied before disconnecting.

- [ ] **Step 7: Commit capture**

```bash
git add BookmarkShareExtension BookmarkCollections.xcodeproj BookmarkCollectionsTests/ShareCaptureModelTests.swift
git commit -m "feat: add bookmark share extension"
```

### Task 9: Add Settings, sync health, platform commands, and accessibility polish

**Files:**
- Create: `BookmarkCollections/Domain/SyncHealthMonitor.swift`
- Create: `BookmarkCollections/Features/Settings/SettingsView.swift`
- Create: `BookmarkCollections/Features/Settings/ImportSummaryView.swift`
- Create: `BookmarkCollections/Commands/BookmarkCommands.swift`
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift`
- Modify: `BookmarkCollections/Features/Library/BookmarkCard.swift`
- Modify: `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift`

**Interfaces:**
- Produces: Settings import/export UI, honest iCloud account status, Mac commands, VoiceOver labels, and keyboard/focus behavior.

- [ ] **Step 1: Add failing tests for visible accessibility and Settings flows**

  Assert a bookmark card exposes title, domain, collection, and Favorite state in its accessibility value; Settings exposes Import Links, Export HTML, Export JSON, and iCloud account status; and destructive export/import errors do not dismiss their sheet silently.

- [ ] **Step 2: Implement sync health without inventing a last-sync timestamp**

  `SyncHealthMonitor` calls `CKContainer.accountStatus()` and publishes `.available`, `.noAccount`, `.restricted`, `.temporarilyUnavailable`, or `.error(message)`. Refresh on app activation and account-change notification. Copy says only what is known; it never claims that all records are synchronized.

- [ ] **Step 3: Build Settings import/export**

  Use `fileImporter` for `.plainText` and JSON and `fileExporter` for HTML/JSON. Present `ImportSummaryView` with counts for new, duplicate, restored, and invalid lines. Write through the system exporter so cancellation and replacement remain system-managed and atomic.

- [ ] **Step 4: Add Mac commands and selection behavior**

  Provide Command-N Add Link, Command-F Search, Command-Shift-N New Collection, Delete Move to Recently Deleted, and standard Open/Share commands only when selection supports them. Use native Commands and focused values.

- [ ] **Step 5: Audit accessibility and appearances**

  Add combined card labels/values, mark preview images decorative, verify controls use semantic labels and minimum targets, and test light/dark plus accessibility Dynamic Type. Fix truncation using flexible layouts rather than fixed font sizes.

- [ ] **Step 6: Run full automated tests and commit**

```bash
xcodebuild test -scheme BookmarkCollections -destination 'platform=macOS'
xcodebuild test -scheme BookmarkCollections -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
git add BookmarkCollections BookmarkCollectionsUITests
git commit -m "feat: add settings sync status and accessibility"
```

### Task 10: Verify CloudKit, migration safety, and release readiness

**Files:**
- Create: `docs/verification/cloudkit-device-matrix.md`
- Create: `README.md`
- Create: `CHANGELOG.md`
- Create: `DECISIONS.md`
- Create: `TODO.md`

**Interfaces:**
- Produces: real-device synchronization evidence, backup recovery evidence, and current project documentation.

- [ ] **Step 1: Run the complete clean verification suite**

```bash
xcodebuild clean test -scheme BookmarkCollections -destination 'platform=macOS'
xcodebuild test -scheme BookmarkCollections -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild analyze -scheme BookmarkCollections -destination 'generic/platform=iOS'
```

  Expected: all tests PASS and Analyze reports no new warnings.

- [ ] **Step 2: Exercise the real-device sync matrix**

  On one iPhone, one iPad, and one Mac signed into the same development iCloud account, record pass/fail for: create, favorite, move, rename collection, soft delete, restore, permanent delete, and preview arrival. Then edit the same bookmark offline on two devices, reconnect, and verify the documented most-recently-modified rule. Save the dated results in `docs/verification/cloudkit-device-matrix.md`.

- [ ] **Step 3: Verify independent offline saves of the same URL**

  Save the same tracked URL on two offline devices with different collection/favorite choices. Reconnect and verify reconciliation produces one canonical record, Favorite is preserved if either was true, and the most recently modified title/collection wins.

- [ ] **Step 4: Verify backup recovery**

  Export JSON and HTML from a seeded library. Import JSON into a fresh local store and compare bookmark UUIDs, URLs, titles, collections/order, favorites, and dates. Import the HTML into Safari to confirm portability. Record the result in the verification document.

- [ ] **Step 5: Complete a manual quality pass**

  Verify Share Sheet saving with network disabled, relaunch persistence, metadata failure fallback, empty states, VoiceOver, keyboard-only Mac operation, accessibility text sizes, light/dark appearance, and destructive confirmations.

- [ ] **Step 6: Deploy the CloudKit production schema before distribution**

  In CloudKit Console, inspect the Development schema created by the signed builds, verify only the intended bookmark and collection record types/fields exist, then deploy that schema to Production. Re-run a TestFlight build against Production and verify a new account can create and synchronize its first bookmark.

- [ ] **Step 7: Update durable project documentation**

  README documents build requirements, entitlements, architecture, and import/export. CHANGELOG records the v1 implementation. DECISIONS records local-first SwiftData/CloudKit, single-collection membership, and portable backup choices. TODO contains only genuinely deferred work from the approved exclusions.

- [ ] **Step 8: Commit verification and documentation**

```bash
git add docs README.md CHANGELOG.md DECISIONS.md TODO.md
git commit -m "docs: verify universal bookmark app v1"
```

## Execution checkpoints

- After Task 2: launch both platforms before building domain behavior.
- After Task 6: create a sample text list and prove import/export round trips before UI work depends on them.
- After Task 8: stop if the Share Extension cannot reliably access the App Group store; do not mask the failure with an in-memory queue.
- After Task 9: run a fresh code review before real-device CloudKit testing.
- Task 10 is mandatory release evidence; simulator success does not substitute for multi-device CloudKit validation.

## Definition of done

- Every automated test in this plan passes on macOS and an iPhone simulator.
- The app and Share Extension build from a clean checkout with documented signing setup.
- A Share Sheet save confirms only after the URL is durable in the local store.
- All Items, Favorites, single-membership Collections, search/sort, and Recently Deleted behave as specified.
- Offline and failed-metadata states never lose a valid URL.
- JSON restores user-authored data and organization; HTML opens in a standard browser bookmark importer.
- Real iPhone, iPad, and Mac testing demonstrates CloudKit propagation and offline conflict behavior.
- VoiceOver, Dynamic Type, keyboard interaction, light/dark appearance, and destructive confirmations pass manual checks.
