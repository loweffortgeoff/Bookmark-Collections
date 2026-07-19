# Info Panel + Image Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a context-menu "Get Info" panel for bookmarks, and image import via the share extension with Images/Links sidebar filters and a full-screen viewer.

**Architecture:** The info panel is a new sheet (`BookmarkInfoView`) wired through the existing `SheetDestination` pattern in `LibraryRootView`. Images become a second `kind` on the existing `Bookmark` model (image bytes in the existing `previewImageData` external-storage field), so collections, favorites, soft delete, and CloudKit sync work unchanged. Dedup reconciliation and metadata enrichment skip image-kind items.

**Tech Stack:** SwiftUI, SwiftData (+CloudKit), XCTest. No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-07-19-info-panel-and-image-import-design.md`

## Global Constraints

- Swift 6, iOS 18+, macOS 15+, Xcode 26.6+ (README floor).
- No third-party dependencies. SwiftUI only, no UIKit/AppKit beyond the existing platform-conditional image/pasteboard helpers.
- New `Bookmark` fields MUST have default values (CloudKit requirement; existing model style).
- Match existing code style exactly (see neighboring files); no drive-by refactors.
- All work on branch `feature/info-panel-and-image-import` (create from `main` before Task 1; use a worktree per superpowers:using-git-worktrees if executing with subagents).
- Unit test command (expected `** TEST SUCCEEDED **`):
  ```bash
  xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections \
    -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests
  ```
- UI test command (expected `** TEST SUCCEEDED **`):
  ```bash
  xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections \
    -destination 'platform=macOS' -only-testing:BookmarkCollectionsUITests
  ```
- New user-facing views: Dynamic Type (no hardcoded font sizes), accessibility identifiers/labels, light+dark supported automatically via system styles.

---

### Task 1: Link Info Panel (BookmarkInfoView + Get Info menu item)

**Files:**
- Create: `BookmarkCollections/Features/Bookmark/BookmarkInfoView.swift`
- Modify: `BookmarkCollections/Features/Bookmark/BookmarkActions.swift`
- Modify: `BookmarkCollections/Features/Library/LibraryGridView.swift`
- Modify: `BookmarkCollections/Features/Library/LibraryRootView.swift`
- Test: `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift`

**Interfaces:**
- Consumes: `Bookmark`, `BookmarkCollection`, `BookmarkRepository.setFavorite(_:to:)`, `BookmarkRepository.move(_:to:)` (all existing).
- Produces: `BookmarkInfoView(bookmark:)` view; `BookmarkActions` gains required `onInfo: () -> Void` parameter (declared after `onEdit`); `LibraryGridView` gains required `onInfo: (Bookmark) -> Void` parameter (declared after `onEdit`); `SheetDestination.bookmarkInfo(Bookmark)`. Task 7 later wraps the URL section in a `kind == .link` check — write it unconditional here.

- [ ] **Step 1: Write the failing UI test**

Append to `BookmarkCollectionsUITests.swift` (inside the class, after `testSeededCardOpensEditorFromContextMenu`, reusing the file's existing `identified`/`activate`/`activateContextMenu`/`contextMenuItem`/`showSidebarIfNeeded` helpers):

```swift
    func testSeededCardOpensInfoPanelFromContextMenu() {
        showSidebarIfNeeded()
        activate(destinationElement("destination.allItems"))
        let card = identified("bookmark.seeded-active")
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        activateContextMenu(on: card)
        activate(contextMenuItem("Get Info"))

        XCTAssertTrue(identified("bookmarkInfo").waitForExistence(timeout: 2))
    }
```

- [ ] **Step 2: Run it to verify it fails**

Run the UI test command (Global Constraints) with `-only-testing:BookmarkCollectionsUITests/BookmarkCollectionsUITests/testSeededCardOpensInfoPanelFromContextMenu`.
Expected: FAIL (no "Get Info" menu item exists).

- [ ] **Step 3: Create BookmarkInfoView**

New file `BookmarkCollections/Features/Bookmark/BookmarkInfoView.swift`:

```swift
import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct BookmarkInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \BookmarkCollection.sortPosition) private var collections: [BookmarkCollection]

    let bookmark: Bookmark
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        if let url = URL(string: bookmark.urlString) { openURL(url) }
                    } label: {
                        Text(bookmark.urlString)
                            .font(.callout)
                            .foregroundStyle(.tint)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open link")
                    Button("Copy URL", systemImage: "doc.on.doc", action: copyURL)
                }
                Section {
                    Text(bookmark.title.isEmpty ? bookmark.domain : bookmark.title)
                        .font(.headline)
                }
                Section("Organization") {
                    Picker("Collection", selection: collectionSelection) {
                        Text("None").tag(nil as UUID?)
                        ForEach(collections) { collection in
                            Text(collection.name).tag(collection.id as UUID?)
                        }
                    }
                    Toggle("Favorite", isOn: favoriteSelection)
                }
                Section("Details") {
                    LabeledContent("Added", value: bookmark.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Modified", value: bookmark.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Info")
            .accessibilityIdentifier("bookmarkInfo")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 380, minHeight: 440)
    }

    private var collectionSelection: Binding<UUID?> {
        Binding(
            get: { bookmark.collection?.id },
            set: { id in
                perform {
                    try BookmarkRepository(context: modelContext)
                        .move(bookmark, to: collections.first(where: { $0.id == id }))
                }
            }
        )
    }

    private var favoriteSelection: Binding<Bool> {
        Binding(
            get: { bookmark.isFavorite },
            set: { favorite in
                perform {
                    try BookmarkRepository(context: modelContext).setFavorite(bookmark, to: favorite)
                }
            }
        )
    }

    private func copyURL() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(bookmark.urlString, forType: .string)
        #else
        UIPasteboard.general.string = bookmark.urlString
        #endif
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 4: Add Get Info to BookmarkActions**

In `BookmarkActions.swift`, add the parameter after `onEdit` (line 8):

```swift
    let onEdit: () -> Void
    let onInfo: () -> Void
```

In the non-deleted branch, insert as the FIRST item, above the Favorite button (before line 22):

```swift
            Button("Get Info", systemImage: "info.circle") { onInfo() }
```

- [ ] **Step 5: Thread onInfo through LibraryGridView**

In `LibraryGridView.swift`, add after `let onEdit: (Bookmark) -> Void` (line 14):

```swift
    let onInfo: (Bookmark) -> Void
```

In the `.contextMenu` block (lines 66–74), pass it after `onEdit`:

```swift
                                            onEdit: { onEdit(bookmark) },
                                            onInfo: { onInfo(bookmark) },
```

- [ ] **Step 6: Wire the sheet in LibraryRootView**

In `LibraryRootView.swift`:

1. In the `LibraryGridView(...)` call (after `onEdit:`, line 92):

```swift
                onEdit: { sheet = .editBookmark($0) },
                onInfo: { sheet = .bookmarkInfo($0) },
```

2. Add a case to `SheetDestination` (after `editBookmark`, line 246):

```swift
    case bookmarkInfo(Bookmark)
```

and to its `id` switch (after the `editBookmark` line):

```swift
        case let .bookmarkInfo(bookmark): "info-\(bookmark.id)"
```

3. In `sheetContent(for:)` (after the `.editBookmark` case, line 135):

```swift
        case let .bookmarkInfo(bookmark):
            BookmarkInfoView(bookmark: bookmark)
```

- [ ] **Step 7: Run the UI test to verify it passes**

Run the same single-test UI command as Step 2. Expected: PASS.

- [ ] **Step 8: Run the full unit suite (regression)**

Run the unit test command (Global Constraints). Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add BookmarkCollections BookmarkCollectionsUITests
git commit -m "feat: add Get Info panel to bookmark context menu"
```

---

### Task 2: Bookmark.kind model field

**Files:**
- Modify: `BookmarkCollections/Data/Bookmark.swift`
- Test: `BookmarkCollectionsTests/BookmarkRepositoryTests.swift`

**Interfaces:**
- Produces: `Bookmark.Kind` (`String`-backed enum, cases `link`, `image`), stored `kindRawValue: String` defaulting to `link` (CloudKit-safe), computed `kind: Kind`. Every later task reads `bookmark.kind`.

- [ ] **Step 1: Write the failing test**

Append inside the class in `BookmarkRepositoryTests.swift` (reuse the file's existing container/repository setup helpers if present; otherwise construct `ModelContainerFactory.make(inMemory: true, cloudKit: false)` as `ShareCaptureModelTests` does):

```swift
    func testBookmarkDefaultsToLinkKindAndRoundTripsImage() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = Bookmark(urlString: "https://example.com/kind", normalizedURLString: "https://example.com/kind")
        container.mainContext.insert(bookmark)
        try container.mainContext.save()

        XCTAssertEqual(bookmark.kind, .link)

        bookmark.kind = .image
        try container.mainContext.save()
        XCTAssertEqual(bookmark.kindRawValue, Bookmark.Kind.image.rawValue)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run the unit test command with `-only-testing:BookmarkCollectionsTests/BookmarkRepositoryTests/testBookmarkDefaultsToLinkKindAndRoundTripsImage`.
Expected: FAIL to compile ("`kind` is not a member of `Bookmark`").

- [ ] **Step 3: Add the field**

In `Bookmark.swift`, add after the `MetadataState` enum (line 10):

```swift
    enum Kind: String, Codable, CaseIterable {
        case link
        case image
    }
```

Add the stored property after `metadataStateRawValue`/`lastMetadataRefreshAt` (after line 25):

```swift
    var kindRawValue: String = Kind.link.rawValue
```

Add the computed property after the `metadataState` computed property (after line 30):

```swift
    var kind: Kind {
        get { Kind(rawValue: kindRawValue) ?? .link }
        set { kindRawValue = newValue.rawValue }
    }
```

The `init` is unchanged (default covers it).

- [ ] **Step 4: Run test to verify it passes**

Same command as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BookmarkCollections/Data/Bookmark.swift BookmarkCollectionsTests/BookmarkRepositoryTests.swift
git commit -m "feat: add link/image kind to Bookmark model"
```

---

### Task 3: Repository saveImage + kind-aware dedup and enrichment

**Files:**
- Modify: `BookmarkCollections/Domain/BookmarkRepository.swift`
- Modify: `BookmarkCollections/Domain/MetadataEnricher.swift`
- Test: `BookmarkCollectionsTests/BookmarkRepositoryTests.swift`
- Test: `BookmarkCollectionsTests/MetadataEnricherTests.swift`

**Interfaces:**
- Consumes: `Bookmark.kind` (Task 2).
- Produces: `BookmarkRepository.saveImage(data: Data, title: String, collection: BookmarkCollection?, favorite: Bool) throws -> Bookmark`. `reconcileDuplicates()` and `MetadataEnricher` ignore image-kind bookmarks.

- [ ] **Step 1: Write the failing repository tests**

Append inside the class in `BookmarkRepositoryTests.swift`:

```swift
    func testSaveImageCreatesImageBookmark() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let data = Data([0x89, 0x50, 0x4E, 0x47])

        let bookmark = try repository.saveImage(data: data, title: "Screenshot", favorite: true)

        XCTAssertEqual(bookmark.kind, .image)
        XCTAssertEqual(bookmark.title, "Screenshot")
        XCTAssertEqual(bookmark.previewImageData, data)
        XCTAssertTrue(bookmark.urlString.isEmpty)
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertEqual(bookmark.metadataState, .ready)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Bookmark>()).count, 1)
    }

    func testReconcileDuplicatesIgnoresImageBookmarks() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        _ = try repository.saveImage(data: Data([0x01]), title: "First")
        _ = try repository.saveImage(data: Data([0x02]), title: "Second")

        try repository.reconcileDuplicates()

        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Bookmark>()).count, 2)
    }
```

The second test is the load-bearing one: both image bookmarks share the empty `normalizedURLString`, so today's `reconcileDuplicates()` would group and delete one of them.

- [ ] **Step 2: Run tests to verify they fail**

Run the unit test command with `-only-testing:BookmarkCollectionsTests/BookmarkRepositoryTests`.
Expected: FAIL to compile ("no member `saveImage`").

- [ ] **Step 3: Implement saveImage and the reconcile guard**

In `BookmarkRepository.swift`, add after the `save(url:collection:favorite:)` method (after line 58):

```swift
    @discardableResult
    func saveImage(
        data: Data,
        title: String,
        collection: BookmarkCollection? = nil,
        favorite: Bool = false
    ) throws -> Bookmark {
        let now = Date()
        let bookmark = Bookmark(urlString: "", normalizedURLString: "", createdAt: now)
        bookmark.kind = .image
        bookmark.title = title
        bookmark.previewImageData = data
        bookmark.collection = collection
        bookmark.isFavorite = favorite
        bookmark.metadataState = .ready
        context.insert(bookmark)
        try context.save()
        return bookmark
    }
```

In `reconcileDuplicates()`, change line 61 from:

```swift
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
```

to:

```swift
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
            .filter { $0.kind == .link }
```

- [ ] **Step 4: Run repository tests to verify they pass**

Same command as Step 2. Expected: PASS (all tests in the file).

- [ ] **Step 5: Write the failing enricher test**

Append inside the class in `MetadataEnricherTests.swift` (self-contained stub so it doesn't depend on the file's existing fixtures; if the file already defines an identical-purpose recording provider, reuse it instead of adding this one):

```swift
    func testEnrichmentSkipsImageBookmarks() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let image = try BookmarkRepository(context: container.mainContext)
            .saveImage(data: Data([0x01]), title: "Screenshot")
        image.metadataState = .pending
        try container.mainContext.save()
        let provider = FailingIfCalledProvider()
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.enrichPending(limit: 10)
        try await enricher.refresh(image)

        XCTAssertEqual(image.metadataState, .pending)
    }

    private struct FailingIfCalledProvider: MetadataProviding {
        func metadata(for url: URL) async throws -> LinkMetadata {
            XCTFail("Image bookmarks must not be enriched")
            return LinkMetadata(domain: "")
        }
    }
```

Note: the image bookmark's `urlString` is empty, so today's `refresh` would flip it to `.failed` — the assertion catches that.

- [ ] **Step 6: Run it to verify it fails**

Run with `-only-testing:BookmarkCollectionsTests/MetadataEnricherTests/testEnrichmentSkipsImageBookmarks`.
Expected: FAIL (`metadataState` becomes `.failed`).

- [ ] **Step 7: Implement the enricher guards**

In `MetadataEnricher.swift`, change the `pending` filter (line 17) from:

```swift
        let pending = bookmarks.lazy.filter { $0.metadataState == .pending }.prefix(limit)
```

to:

```swift
        let pending = bookmarks.lazy
            .filter { $0.kind == .link && $0.metadataState == .pending }
            .prefix(limit)
```

In `refresh(_:)`, add as the first line of the method body (before `let refreshDate = Date()`, line 25):

```swift
        guard bookmark.kind == .link else { return }
```

- [ ] **Step 8: Run the full unit suite**

Run the unit test command (all of `BookmarkCollectionsTests`). Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add BookmarkCollections/Domain BookmarkCollectionsTests
git commit -m "feat: image-kind bookmarks in repository, dedup, and enrichment"
```

---

### Task 4: Shared ImageDownsampler

**Files:**
- Create: `BookmarkCollections/Domain/ImageDownsampler.swift`
- Modify: `BookmarkCollections/Domain/MetadataProvider.swift`
- Modify: `BookmarkCollections.xcodeproj/project.pbxproj`
- Test: `BookmarkCollectionsTests/MetadataEnricherTests.swift` (regression only — no new test file; the downsampler is exercised by Task 5's tests)

**Interfaces:**
- Produces: `ImageDownsampler.downsample(_ data: Data, maximumPixelSize: Int) -> Data` and `ImageDownsampler.isValidImage(_ data: Data) -> Bool`, available to BOTH the app and share-extension targets.

This is a move-only extraction of the private `downsample` in `MetadataProvider.swift:63-88` plus one new validity helper, so the share extension (Task 5) can reuse the 1200px pipeline.

- [ ] **Step 1: Create the file**

New file `BookmarkCollections/Domain/ImageDownsampler.swift` (body of `downsample` copied verbatim from `MetadataProvider.swift:63-88`):

```swift
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageDownsampler {
    static func isValidImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 0
    }

    static func downsample(_ data: Data, maximumPixelSize: Int) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return data
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return data
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return data
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return data }
        return output as Data
    }
}
```

- [ ] **Step 2: Delegate from MetadataProvider**

In `MetadataProvider.swift`, replace the private `downsample` method (lines 63–88) with nothing (delete it), and change its call site (line 60) from:

```swift
        return downsample(data, maximumPixelSize: 1_200)
```

to:

```swift
        return ImageDownsampler.downsample(data, maximumPixelSize: 1_200)
```

Keep the `ImageIO` and `UniformTypeIdentifiers` imports in `MetadataProvider.swift` only if still referenced; after this change `ImageIO` is no longer used there — remove that import line. (`UniformTypeIdentifiers` is still used at line 50.)

- [ ] **Step 3: Add the file to the share-extension target**

In `BookmarkCollections.xcodeproj/project.pbxproj`, find the exception set `AA10000000000000000000B2 /* Exceptions for "BookmarkCollections" folder in "BookmarkShareExtension" target */` and add one line to `membershipExceptions`, keeping alphabetical order:

```
				Domain/BookmarkRepository.swift,
				Domain/ImageDownsampler.swift,
				Domain/MetadataProvider.swift,
```

(The app target picks the file up automatically via the synchronized root group; only the extension needs this explicit line.)

- [ ] **Step 4: Verify both targets still build and tests pass**

```bash
xcodebuild build -project BookmarkCollections.xcodeproj -scheme BookmarkCollections \
  -destination 'generic/platform=iOS'
```
Expected: `** BUILD SUCCEEDED **` (this scheme builds the extension too).

Then run the unit test command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add BookmarkCollections/Domain BookmarkCollections.xcodeproj/project.pbxproj
git commit -m "refactor: extract shared ImageDownsampler for app and extension"
```

---

### Task 5: Share extension accepts images

**Files:**
- Modify: `BookmarkShareExtension/ShareCaptureModel.swift`
- Modify: `BookmarkShareExtension/ShareCaptureView.swift`
- Modify: `BookmarkShareExtension/Info.plist`
- Test: `BookmarkCollectionsTests/ShareCaptureModelTests.swift`

**Interfaces:**
- Consumes: `Bookmark.Kind` (Task 2), `BookmarkRepository.saveImage` (Task 3), `ImageDownsampler` (Task 4).
- Produces: `ShareCapture` gains `kind: Bookmark.Kind = .link` (declared FIRST, before `urlString`, so the memberwise init reads `ShareCapture(kind:urlString:suggestedTitle:faviconData:previewImageData:)`; existing call sites compile via the default). Image captures carry bytes in the existing `previewImageData` field.

- [ ] **Step 1: Write the failing tests**

Append inside the class in `ShareCaptureModelTests.swift`:

```swift
    func testImageAttachmentLoadsAsImageCapture() async throws {
        let model = try makeModel()
        let provider = NSItemProvider(
            item: try onePixelPNG() as NSData,
            typeIdentifier: UTType.png.identifier
        )

        await model.load(from: [provider])

        XCTAssertEqual(model.capture?.kind, .image)
        XCTAssertNotNil(model.capture?.previewImageData)
        XCTAssertEqual(model.capture?.urlString, "")
        XCTAssertEqual(model.state, .ready)
    }

    func testImageSavePersistsImageBookmark() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let provider = NSItemProvider(
            item: try onePixelPNG() as NSData,
            typeIdentifier: UTType.png.identifier
        )
        await model.load(from: [provider])

        model.save(collectionID: nil, favorite: true)

        let bookmark = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(bookmark.kind, .image)
        XCTAssertNotNil(bookmark.previewImageData)
        XCTAssertTrue(bookmark.urlString.isEmpty)
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertFalse(bookmark.title.isEmpty)
        XCTAssertEqual(bookmark.metadataState, .ready)
        XCTAssertEqual(model.state, .saved)
    }

    func testJunkDataTypedAsImageFails() async throws {
        let model = try makeModel()
        let provider = NSItemProvider(
            item: Data([0x00, 0x01, 0x02]) as NSData,
            typeIdentifier: UTType.png.identifier
        )

        await model.load(from: [provider])

        guard case .failed = model.state else {
            return XCTFail("Expected junk image data to fail")
        }
    }

    /// Smallest valid PNG: 1x1 transparent pixel.
    private func onePixelPNG() throws -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        return try XCTUnwrap(Data(base64Encoded: base64))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run with `-only-testing:BookmarkCollectionsTests/ShareCaptureModelTests`.
Expected: new tests FAIL (compile error on `capture?.kind`, or state `.failed("Share a web link…")`).

- [ ] **Step 3: Extend ShareCapture and the load path**

In `ShareCaptureModel.swift`:

1. Change the struct (lines 6–11) to:

```swift
struct ShareCapture: Equatable {
    var kind: Bookmark.Kind = .link
    let urlString: String
    var suggestedTitle: String?
    var faviconData: Data?
    var previewImageData: Data?
}
```

2. In `load(from:)` (lines 81–99), replace the body between `let directURL…` and the closing brace with:

```swift
        let directURL = await firstURL(from: providers)
        let loaded: ShareCapture?
        if let directURL {
            loaded = directURL
        } else if let textURL = await firstURL(inTextFrom: providers) {
            loaded = textURL
        } else {
            loaded = await firstImage(from: providers)
        }
        if let loaded {
            capture = loaded
            state = .ready
            if loaded.kind == .link {
                fetchMetadata(for: loaded)
            }
        } else {
            state = .failed("Share a web link or an image.")
        }
```

(The existing `testUnsupportedInputReportsAUsefulError` asserts the message contains "web link" — the new copy keeps that phrase.)

3. Add the loader (after `firstURL(inTextFrom:)`, around line 175):

```swift
    private func firstImage(from providers: [NSItemProvider]) async -> ShareCapture? {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let data: Data? = await withCheckedContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    continuation.resume(returning: data)
                }
            }
            guard let data, ImageDownsampler.isValidImage(data) else { continue }
            return ShareCapture(
                kind: .image,
                urlString: "",
                suggestedTitle: provider.suggestedName,
                faviconData: nil,
                previewImageData: ImageDownsampler.downsample(data, maximumPixelSize: 1_200)
            )
        }
        return nil
    }
```

- [ ] **Step 4: Branch the save path**

In the context-based `init` (lines 34–67), replace the `saveAction` closure with:

```swift
        saveAction = { capture, collectionID, favorite in
            let collection = try context.fetch(FetchDescriptor<BookmarkCollection>())
                .first(where: { $0.id == collectionID })
            if capture.kind == .image {
                guard let data = capture.previewImageData else {
                    throw ShareCaptureError.missingImageData
                }
                let title: String
                if let suggested = capture.suggestedTitle, !suggested.isEmpty {
                    title = suggested
                } else {
                    title = "Image — \(Date().formatted(date: .abbreviated, time: .omitted))"
                }
                let bookmark = try BookmarkRepository(context: context).saveImage(
                    data: data,
                    title: title,
                    collection: collection,
                    favorite: favorite
                )
                return .created(bookmark)
            }
            let result = try BookmarkRepository(context: context).save(
                url: capture.urlString,
                collection: collection,
                favorite: favorite
            )
            let bookmark = switch result {
            case let .created(bookmark), let .updated(bookmark), let .restored(bookmark): bookmark
            }
            if let title = capture.suggestedTitle, !title.isEmpty {
                bookmark.title = title
            }
            bookmark.faviconData = capture.faviconData
            bookmark.previewImageData = capture.previewImageData
            if capture.suggestedTitle != nil || capture.faviconData != nil || capture.previewImageData != nil {
                bookmark.metadataState = .ready
                bookmark.lastMetadataRefreshAt = Date()
                try? context.save()
            }
            return result
        }
```

Add at file scope (below the `ShareCaptureState` enum):

```swift
enum ShareCaptureError: Error {
    case missingImageData
}
```

- [ ] **Step 5: Update ShareCaptureView**

In `ShareCaptureView.swift` `captureSection` (lines 64–84): change the section header and hide the URL line for images —

```swift
        default:
            if let capture = model.capture {
                Section(capture.kind == .image ? "Image" : "Link") {
                    if let previewData = capture.previewImageData,
                       let preview = UIImage(data: previewData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityHidden(true)
                    }
                    if let title = capture.suggestedTitle, !title.isEmpty {
                        LabeledContent("Title", value: title)
                    }
                    if capture.kind == .link {
                        Text(capture.urlString)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }
            }
```

Also update the loading copy (line 57) from `"Loading shared link…"` to `"Loading shared item…"`.

- [ ] **Step 6: Update the activation rule**

In `BookmarkShareExtension/Info.plist`, inside the `NSExtensionActivationRule` dict, add:

```xml
				<key>NSExtensionActivationSupportsImageWithMaxCount</key>
				<integer>1</integer>
```

- [ ] **Step 7: Run the share model tests, then the full unit suite**

Run with `-only-testing:BookmarkCollectionsTests/ShareCaptureModelTests` — expected: PASS (including the three pre-existing URL tests).
Then the full unit test command — expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add BookmarkShareExtension BookmarkCollectionsTests/ShareCaptureModelTests.swift
git commit -m "feat: accept shared images in the share extension"
```

---

### Task 6: Images and Links library destinations

**Files:**
- Modify: `BookmarkCollections/Features/Library/LibraryDestination.swift`
- Modify: `BookmarkCollections/Features/Collections/CollectionListView.swift`
- Modify: `BookmarkCollections/Features/Library/LibraryGridView.swift` (empty states)
- Test: `BookmarkCollectionsTests/LibraryFilteringTests.swift`

**Interfaces:**
- Consumes: `Bookmark.kind` (Task 2).
- Produces: `LibraryDestination.images` and `.links` cases; sidebar rows `destination.images` / `destination.links`; grid accessibility identifiers `library.images` / `library.links`.

- [ ] **Step 1: Write the failing tests**

Append inside the class in `LibraryFilteringTests.swift`:

```swift
    func testImagesDestinationIncludesOnlyImageKind() {
        let link = Bookmark(urlString: "https://example.com/a", normalizedURLString: "https://example.com/a")
        let image = Bookmark(urlString: "", normalizedURLString: "")
        image.kind = .image
        let deletedImage = Bookmark(urlString: "", normalizedURLString: "")
        deletedImage.kind = .image
        deletedImage.deletedAt = Date()

        XCTAssertTrue(LibraryDestination.images.includes(image))
        XCTAssertFalse(LibraryDestination.images.includes(link))
        XCTAssertFalse(LibraryDestination.images.includes(deletedImage))
    }

    func testLinksDestinationExcludesImageKind() {
        let link = Bookmark(urlString: "https://example.com/a", normalizedURLString: "https://example.com/a")
        let image = Bookmark(urlString: "", normalizedURLString: "")
        image.kind = .image

        XCTAssertTrue(LibraryDestination.links.includes(link))
        XCTAssertFalse(LibraryDestination.links.includes(image))
    }
```

(If this file constructs bookmarks through a local helper, follow its existing construction style instead — the assertions stay the same.)

- [ ] **Step 2: Run tests to verify they fail**

Run with `-only-testing:BookmarkCollectionsTests/LibraryFilteringTests`.
Expected: FAIL to compile ("type `LibraryDestination` has no member `images`").

- [ ] **Step 3: Add the cases**

In `LibraryDestination.swift` add cases after `favorites` (line 5):

```swift
    case links
    case images
```

Extend each switch:

```swift
        // title
        case .links: "Links"
        case .images: "Images"

        // systemImage
        case .links: "link"
        case .images: "photo"

        // accessibilityIdentifier
        case .links: "library.links"
        case .images: "library.images"
```

In `includes(_:)` add after the `.favorites` case:

```swift
        case .links:
            bookmark.deletedAt == nil && bookmark.kind == .link
        case .images:
            bookmark.deletedAt == nil && bookmark.kind == .image
```

- [ ] **Step 4: Add sidebar rows**

In `CollectionListView.swift`, extend the Library section (lines 15–18) to match the design's order (All Items, Images, Links, Favorites):

```swift
            Section("Library") {
                destinationRow(.allItems, title: "All Items", identifier: "destination.allItems")
                destinationRow(.images, title: "Images", identifier: "destination.images")
                destinationRow(.links, title: "Links", identifier: "destination.links")
                destinationRow(.favorites, title: "Favorites", identifier: "destination.favorites")
            }
```

- [ ] **Step 5: Add empty states**

In `LibraryGridView.swift` `emptyState` switch (lines 182–209), add before the `.allItems` case:

```swift
            case .images:
                ContentUnavailableView(
                    "No Images",
                    systemImage: "photo",
                    description: Text("Share a screenshot or image from another app to save it here.")
                )
            case .links:
                ContentUnavailableView(
                    "No Links",
                    systemImage: "link",
                    description: Text("Share a link from another app or add one here.")
                )
```

Also update the Select-button guard at line 30 — no change needed (`destination != .recentlyDeleted` still holds), and the `.dropDestination` and selection logic are kind-agnostic.

- [ ] **Step 6: Run the filtering tests, then the full unit suite**

Run with `-only-testing:BookmarkCollectionsTests/LibraryFilteringTests` — expected: PASS.
Then the full unit test command — expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add BookmarkCollections BookmarkCollectionsTests/LibraryFilteringTests.swift
git commit -m "feat: add Images and Links sidebar destinations"
```

---

### Task 7: Image-aware cards, context menu, viewer, and info panel

**Files:**
- Create: `BookmarkCollections/Features/Bookmark/ImageViewerView.swift`
- Modify: `BookmarkCollections/Features/Bookmark/BookmarkActions.swift`
- Modify: `BookmarkCollections/Features/Bookmark/BookmarkInfoView.swift`
- Modify: `BookmarkCollections/Features/Library/LibraryGridView.swift`
- Modify: `BookmarkCollections/Features/Library/LibraryRootView.swift`
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift` (UI-test seed)
- Test: `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift`

**Interfaces:**
- Consumes: `Bookmark.kind`, `LibraryDestination.images`, `BookmarkInfoView`, `SheetDestination`.
- Produces: `ImageViewerView(bookmark:)`; `LibraryGridView` gains required `onOpenImage: (Bookmark) -> Void` (declared after `onInfo`); `SheetDestination.imageViewer(Bookmark)`; UI-test seed image bookmark with fixed id `"11111111-1111-1111-1111-111111111111"` (card identifier `bookmark.11111111-1111-1111-1111-111111111111`).

- [ ] **Step 1: Write the failing UI test**

Append inside the class in `BookmarkCollectionsUITests.swift`:

```swift
    func testImagesDestinationShowsOnlyImageItems() {
        showSidebarIfNeeded()
        activate(destinationElement("destination.images"))

        let imageCard = identified("bookmark.11111111-1111-1111-1111-111111111111")
        XCTAssertTrue(imageCard.waitForExistence(timeout: 5))
        XCTAssertFalse(identified("bookmark.seeded-active").exists)
    }
```

- [ ] **Step 2: Run it to verify it fails**

Run the UI test command with `-only-testing:BookmarkCollectionsUITests/BookmarkCollectionsUITests/testImagesDestinationShowsOnlyImageItems`.
Expected: FAIL (no seeded image bookmark exists).

- [ ] **Step 3: Seed an image bookmark for UI tests**

In `BookmarkCollectionsApp.swift` `seedUITestLibrary` (lines 53–79), add before `try? context.save()`:

```swift
        let image = Bookmark(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            urlString: "",
            normalizedURLString: ""
        )
        image.kind = .image
        image.title = "Seeded Image"
        image.metadataState = .ready
        image.previewImageData = solidPreviewData(width: 640, height: 480, red: 0.85, green: 0.60, blue: 0.20)
        context.insert(image)
```

- [ ] **Step 4: Create ImageViewerView**

New file `BookmarkCollections/Features/Bookmark/ImageViewerView.swift`:

```swift
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ImageViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let bookmark: Bookmark

    @State private var zoom: CGFloat = 1
    @State private var gestureZoom: CGFloat = 1

    var body: some View {
        NavigationStack {
            Group {
                if let image = viewerImage {
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(zoom * gestureZoom)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    gestureZoom = value.magnification
                                }
                                .onEnded { value in
                                    zoom = min(max(zoom * value.magnification, 1), 8)
                                    gestureZoom = 1
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.snappy) {
                                zoom = zoom > 1 ? 1 : 2
                            }
                        }
                        .accessibilityLabel(bookmark.title)
                } else {
                    ContentUnavailableView("Image Unavailable", systemImage: "photo")
                }
            }
            .navigationTitle(bookmark.title)
            .accessibilityIdentifier("imageViewer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let image = viewerImage {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(
                            item: image,
                            preview: SharePreview(bookmark.title, image: image)
                        )
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    private var viewerImage: Image? {
        guard let data = bookmark.previewImageData else { return nil }
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #endif
    }
}
```

- [ ] **Step 5: Make BookmarkActions kind-aware**

In `BookmarkActions.swift`:

1. Add platform imports at the top (after `import SwiftUI`):

```swift
#if os(macOS)
import AppKit
#else
import UIKit
#endif
```

2. In the non-deleted branch, wrap the two link-only actions. Replace:

```swift
            ShareLink(item: URL(string: bookmark.urlString)!)
            Button("Refresh Preview", systemImage: "arrow.clockwise") {
```

with:

```swift
            if bookmark.kind == .link {
                ShareLink(item: URL(string: bookmark.urlString)!)
            } else if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview(bookmark.title, image: shareImage))
            }
            if bookmark.kind == .link {
                Button("Refresh Preview", systemImage: "arrow.clockwise") {
```

(closing the added brace after that button's closure ends, before `Divider()`).

3. Add the helper below `perform`:

```swift
    private var shareImage: Image? {
        guard bookmark.kind == .image, let data = bookmark.previewImageData else { return nil }
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #endif
    }
```

- [ ] **Step 6: Route image taps to the viewer**

1. In `LibraryGridView.swift`, add after `let onInfo: (Bookmark) -> Void`:

```swift
    let onOpenImage: (Bookmark) -> Void
```

and change the `BookmarkCard` construction (lines 53–57) to:

```swift
                                        BookmarkCard(
                                            bookmark: bookmark,
                                            onOpen: cardOpenAction(for: bookmark),
                                            onCommandSelection: { onCommandSelection(bookmark) }
                                        )
```

with this helper added below `toggleSelection`:

```swift
    private func cardOpenAction(for bookmark: Bookmark) -> (() -> Void)? {
        if isSelecting { return { toggleSelection(bookmark) } }
        if bookmark.kind == .image { return { onOpenImage(bookmark) } }
        return nil
    }
```

2. In `LibraryRootView.swift`:
   - Pass it in the `LibraryGridView(...)` call after `onInfo:`:

```swift
                onOpenImage: { sheet = .imageViewer($0) },
```

   - Add to `SheetDestination` after `bookmarkInfo`:

```swift
    case imageViewer(Bookmark)
```

   - `id` switch:

```swift
        case let .imageViewer(bookmark): "viewer-\(bookmark.id)"
```

   - `sheetContent(for:)`:

```swift
        case let .imageViewer(bookmark):
            ImageViewerView(bookmark: bookmark)
```

- [ ] **Step 7: Hide the URL section for images in the info panel**

In `BookmarkInfoView.swift`, wrap the first `Section { … Copy URL … }` (the URL section from Task 1) in:

```swift
                if bookmark.kind == .link {
                    Section {
                        ...unchanged contents...
                    }
                }
```

- [ ] **Step 8: Run the UI test to verify it passes**

Same single-test command as Step 2. Expected: PASS.

- [ ] **Step 9: Run both full suites**

Run the unit test command, then the UI test command (Global Constraints). Expected: `** TEST SUCCEEDED **` twice.

- [ ] **Step 10: Commit**

```bash
git add BookmarkCollections BookmarkCollectionsUITests
git commit -m "feat: image cards, full-screen viewer, and kind-aware actions"
```

---

### Task 8: Final verification and docs

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `TODO.md` (move shipped items to Done with 2026-07-19; add Backlog entries below)

**Backlog entries to add to TODO.md (deferred by the spec):**
- Photos-picker in-app image import
- Files-importer image import (Mac)
- Drag & drop image import (Mac/iPad)
- `pageDescription` field + og:description fetch for the info panel
- Tags system

- [ ] **Step 1: Full build + both suites**

```bash
xcodebuild build -project BookmarkCollections.xcodeproj -scheme BookmarkCollections \
  -destination 'generic/platform=iOS'
```
Expected: `** BUILD SUCCEEDED **`. Then run the unit test command and the UI test command. Expected: `** TEST SUCCEEDED **` twice.

- [ ] **Step 2: Update CHANGELOG.md**

Add under an in-flight/unreleased heading, following the file's existing format:

```markdown
- Added: Get Info panel on the bookmark context menu (URL, title, collection, favorite, added/modified dates).
- Added: Save images and screenshots via the Share Sheet; new Images and Links sidebar filters; full-screen image viewer.
```

- [ ] **Step 3: Update TODO.md**

Move the shipped feature items to Done dated 2026-07-19 and add the Backlog entries listed above (create the Backlog section if missing).

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md TODO.md
git commit -m "docs: record info panel and image import in changelog and todo"
```

- [ ] **Step 5: Request code review**

Feature is complete on the branch. Dispatch the code-reviewer agent on the full branch diff (`git diff main...HEAD`) before any merge. Simulator/device verification (share an actual screenshot from Photos into Tucked on an iOS simulator) happens before merge per CLAUDE.md — flag this to Geoff; do not merge without it.

---

## Notes for implementers

- **CloudKit:** `kindRawValue` has a default value, so it is a safe additive schema change. The Development schema picks it up automatically on first run; Production deployment is already gated by the project's existing release checklist — nothing extra to do in this plan.
- **Why reconcile MUST skip images:** all image bookmarks share `normalizedURLString == ""`. Without the Task 3 filter, `reconcileDuplicates()` would treat every image as a duplicate of the first one and delete them. This is the highest-risk edge in the whole plan; do not skip its test.
- **Line numbers** referenced in tasks are as of commit `0d9eb28`; verify context before editing if the file has drifted.
