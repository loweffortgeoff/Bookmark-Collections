# Glaze Parity: Text Snippets and Mac Image Import — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a third `text` bookmark kind, teach the JSON backup format the top-level `snippets` key so the Glaze library can move back, and add `File ▸ Add Images…` on macOS.

**Architecture:** `Bookmark` gains one enum case (`.text`) and one defaulted property (`snippetBody`). Snippets reuse the existing `urlString`/`domain` fields for an optional source link and keep `normalizedURLString` empty so link de-duplication never sees them. A new `SnippetEditorView` serves create, edit, and view. Backup gains a parallel `snippets` array alongside `bookmarks`. Add Images routes through the existing `ImageDownsampler` and `BookmarkRepository.saveImage` — no second image path.

**Tech Stack:** Swift 6, SwiftUI, SwiftData + CloudKit, XCTest. No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-08-28-glaze-parity-snippets-design.md`

## Global Constraints

- **Branch:** `feature/snippets-and-add-images`. Never commit to `main`.
- **Both schemes must build after every task.** `Data/Bookmark.swift` and `Domain/BookmarkRepository.swift` compile into `BookmarkShareExtension` as well as the app, so an app-only build can pass while the share extension is broken:
  ```
  xcodebuild -project BookmarkCollections.xcodeproj -scheme "BookmarkCollections" -destination 'generic/platform=iOS Simulator' build
  xcodebuild -project BookmarkCollections.xcodeproj -scheme "BookmarkShareExtension" -destination 'generic/platform=iOS Simulator' build
  ```
  Leave the output verbose. Do **not** add `-quiet` — error parsing tails the log for the first `error:` and `-quiet` strips the surrounding context.
- **No third-party dependencies.**
- **Tests are XCTest**, not Swift Testing. Match the existing suite: `@MainActor final class ... : XCTestCase`, containers built with `try ModelContainerFactory.make(inMemory: true, cloudKit: false)`.
- **Model property is `snippetBody`, never `body`.** The JSON key is `"body"`. The two names meet in the import/export services.
- **Snippets always have `normalizedURLString == ""`** and `metadataState == .ready`.
- **Accessibility identifiers use two prefixes**, matching the existing split: `LibraryDestination.accessibilityIdentifier` returns `library.*` (used on the detail column), while `CollectionListView` sidebar rows pass `destination.*`. Snippets need both: `library.snippets` and `destination.snippets`.
- **Dynamic Type:** never hardcode font sizes. Use text styles.
- **Docs:** `CHANGELOG.md`, `TODO.md`, and `DECISIONS.md` are updated in Task 6, not scattered across tasks.
- **New files join their targets automatically.** The project uses `PBXFileSystemSynchronizedRootGroup`, so a `.swift` file placed in a target's folder compiles into that target with no `project.pbxproj` edit, and a non-source file placed under `BookmarkCollectionsTests/` is copied as a test bundle resource. If a newly created file is somehow not found by the compiler, open the project in Xcode once to let it re-sync before editing the pbxproj by hand.
- **`#if os(macOS)` cannot wrap a labeled argument inside a call.** Swift permits `#if` around declarations, statements, and postfix modifier chains, but not around individual arguments in an argument list. Platform-specific *actions* are therefore declared unconditionally and given a no-op body where they do not apply; only the `Button` declarations and the `.fileImporter` modifier are guarded.
- Unit test command:
  ```
  xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests
  ```

---

### Task 1: Model and repository

**Files:**
- Modify: `BookmarkCollections/Data/Bookmark.swift`
- Modify: `BookmarkCollections/Domain/BookmarkRepository.swift`
- Test: `BookmarkCollectionsTests/SnippetRepositoryTests.swift` (create)

**Interfaces:**
- Consumes: `NormalizedURL(_ value: String) throws`, exposing `.string` and `.url`. `ModelContainerFactory.make(inMemory:cloudKit:)`.
- Produces:
  - `Bookmark.Kind.text`
  - `Bookmark.snippetBody: String` (default `""`)
  - `BookmarkRepository.SnippetError.emptyBody`
  - `static BookmarkRepository.deriveSnippetTitle(_ title: String, body: String) -> String`
  - `BookmarkRepository.saveSnippet(title:body:sourceURL:collection:favorite:) throws -> Bookmark`
  - `BookmarkRepository.updateSnippet(_:title:body:sourceURL:) throws`

- [ ] **Step 1: Write the failing tests**

Create `BookmarkCollectionsTests/SnippetRepositoryTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class SnippetRepositoryTests: XCTestCase {
    func testDerivedTitleUsesTheFirstLineWithContent() {
        let derived = BookmarkRepository.deriveSnippetTitle(
            "",
            body: "\n\n   \nThe first real line\nA second line"
        )

        XCTAssertEqual(derived, "The first real line")
    }

    func testDerivedTitleTruncatesAtEightyCharacters() {
        let longLine = String(repeating: "a", count: 100)

        let derived = BookmarkRepository.deriveSnippetTitle("", body: longLine)

        XCTAssertEqual(derived, String(repeating: "a", count: 80) + "…")
    }

    func testDerivedTitleFallsBackToSnippetForWhitespaceOnlyBodies() {
        XCTAssertEqual(BookmarkRepository.deriveSnippetTitle("", body: "   \n\t\n "), "Snippet")
    }

    func testSuppliedTitleWinsOverDerivation() {
        XCTAssertEqual(
            BookmarkRepository.deriveSnippetTitle("  Chosen Title  ", body: "Ignored first line"),
            "Chosen Title"
        )
    }

    func testSaveSnippetStoresBodyAndKeepsNormalizedURLEmpty() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        let snippet = try repository.saveSnippet(body: "Remember this paragraph.")

        XCTAssertEqual(snippet.kind, .text)
        XCTAssertEqual(snippet.snippetBody, "Remember this paragraph.")
        XCTAssertEqual(snippet.title, "Remember this paragraph.")
        XCTAssertEqual(snippet.normalizedURLString, "")
        XCTAssertEqual(snippet.urlString, "")
        XCTAssertEqual(snippet.domain, "")
        XCTAssertEqual(snippet.metadataState, .ready)
    }

    func testSaveSnippetRecordsAParseableSourceLink() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        let snippet = try repository.saveSnippet(
            body: "A quote worth keeping.",
            sourceURL: "https://Example.com/article#intro"
        )

        XCTAssertEqual(snippet.urlString, "https://Example.com/article#intro")
        XCTAssertEqual(snippet.domain, "example.com")
        XCTAssertEqual(snippet.normalizedURLString, "")
    }

    func testSaveSnippetDropsAnUnparseableSourceLinkRatherThanFailing() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        let snippet = try repository.saveSnippet(body: "Keep the text.", sourceURL: "not a URL")

        XCTAssertEqual(snippet.snippetBody, "Keep the text.")
        XCTAssertEqual(snippet.urlString, "")
        XCTAssertEqual(snippet.domain, "")
    }

    func testSaveSnippetRejectsAnEmptyBody() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        XCTAssertThrowsError(try repository.saveSnippet(body: "   \n  "))
    }

    func testIdenticalSnippetsBothPersist() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        let first = try repository.saveSnippet(body: "Same text")
        let second = try repository.saveSnippet(body: "Same text")

        XCTAssertNotEqual(first.id, second.id)
        let all = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(all.count, 2)
    }

    func testReconcileDuplicatesLeavesSnippetsAlone() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        _ = try repository.saveSnippet(body: "Same text")
        _ = try repository.saveSnippet(body: "Same text")

        try repository.reconcileDuplicates()

        let all = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(all.count, 2)
    }

    func testUpdateSnippetRederivesTheTitleWhenTheTitleIsCleared() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let snippet = try repository.saveSnippet(title: "Original", body: "First body")

        try repository.updateSnippet(snippet, title: "", body: "Replacement body", sourceURL: nil)

        XCTAssertEqual(snippet.snippetBody, "Replacement body")
        XCTAssertEqual(snippet.title, "Replacement body")
    }

    func testUpdateSnippetRejectsAnEmptyBody() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let snippet = try repository.saveSnippet(body: "Original body")

        XCTAssertThrowsError(
            try repository.updateSnippet(snippet, title: "", body: "  ", sourceURL: nil)
        )
        XCTAssertEqual(snippet.snippetBody, "Original body")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/SnippetRepositoryTests
```
Expected: compile failure — `type 'BookmarkRepository' has no member 'deriveSnippetTitle'`, `'saveSnippet'`, `'updateSnippet'`; `'Kind' has no member 'text'`; `'Bookmark' has no member 'snippetBody'`.

- [ ] **Step 3: Add the model case and property**

In `BookmarkCollections/Data/Bookmark.swift`, add `case text` to `Kind`:

```swift
    enum Kind: String, Codable, CaseIterable {
        case link
        case image
        case text
    }
```

And add the stored property immediately after `kindRawValue`:

```swift
    var kindRawValue: String = Kind.link.rawValue
    /// Snippet contents for `.text` bookmarks. Empty for every other kind.
    var snippetBody: String = ""
```

The property must have a default value. CloudKit requires every attribute to be optional or defaulted, and a defaulted `String` keeps this a lightweight migration with no migration plan.

- [ ] **Step 4: Add the repository methods**

In `BookmarkCollections/Domain/BookmarkRepository.swift`, add the error type above `BookmarkRepository`:

```swift
extension BookmarkRepository {
    enum SnippetError: Swift.Error, LocalizedError, Equatable {
        case emptyBody

        var errorDescription: String? {
            switch self {
            case .emptyBody: "A snippet needs some text."
            }
        }
    }
}
```

Then add these members inside `struct BookmarkRepository`, after `saveImage`:

```swift
    /// Fall back to the snippet's first meaningful line when no title was given.
    static func deriveSnippetTitle(_ title: String, body: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }

        let firstLine = body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        if firstLine.isEmpty { return "Snippet" }
        return firstLine.count > 80 ? "\(firstLine.prefix(80))…" : firstLine
    }

    @discardableResult
    func saveSnippet(
        title: String = "",
        body: String,
        sourceURL: String? = nil,
        collection: BookmarkCollection? = nil,
        favorite: Bool = false
    ) throws -> Bookmark {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { throw SnippetError.emptyBody }

        let now = Date()
        // A snippet keeps an empty normalized URL so link de-duplication,
        // which always queries with a parsed NormalizedURL, can never match it.
        let bookmark = Bookmark(urlString: "", normalizedURLString: "", createdAt: now)
        bookmark.kind = .text
        bookmark.snippetBody = trimmedBody
        bookmark.title = Self.deriveSnippetTitle(title, body: trimmedBody)
        Self.applySource(sourceURL, to: bookmark)
        bookmark.collection = collection
        bookmark.isFavorite = favorite
        bookmark.metadataState = .ready
        context.insert(bookmark)
        try context.save()
        return bookmark
    }

    func updateSnippet(
        _ bookmark: Bookmark,
        title: String,
        body: String,
        sourceURL: String?
    ) throws {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { throw SnippetError.emptyBody }

        bookmark.snippetBody = trimmedBody
        bookmark.title = Self.deriveSnippetTitle(title, body: trimmedBody)
        Self.applySource(sourceURL, to: bookmark)
        bookmark.modifiedAt = Date()
        try context.save()
    }

    /// A snippet's source link is optional, so an unparseable one is dropped
    /// rather than costing the user the text they were trying to keep.
    static func applySource(_ sourceURL: String?, to bookmark: Bookmark) {
        let trimmed = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, let normalized = try? NormalizedURL(trimmed) else {
            bookmark.urlString = ""
            bookmark.domain = ""
            return
        }
        bookmark.urlString = trimmed
        bookmark.domain = normalized.url.host?.lowercased() ?? ""
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests
```
Expected: PASS, including the pre-existing suites. `reconcileDuplicates` already filters `kind == .link`, so no existing test should change.

- [ ] **Step 6: Build both schemes**

Run both commands from Global Constraints. Expected: BUILD SUCCEEDED for `BookmarkCollections` and `BookmarkShareExtension`.

- [ ] **Step 7: Commit**

```bash
git add BookmarkCollections/Data/Bookmark.swift BookmarkCollections/Domain/BookmarkRepository.swift BookmarkCollectionsTests/SnippetRepositoryTests.swift
git commit -m "feat: add a text bookmark kind with snippet save and update

A snippet holds a body, an optional derived title, and an optional
source link. It keeps an empty normalized URL so link de-duplication
never matches it, which is what lets two identical snippets both exist.

An unparseable source link is dropped rather than failing the save. A
bad link should not cost the user the text.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Snippets destination and search

**Files:**
- Modify: `BookmarkCollections/Features/Library/LibraryDestination.swift`
- Modify: `BookmarkCollections/Features/Collections/CollectionListView.swift:17-23`
- Test: `BookmarkCollectionsTests/LibraryFilteringTests.swift`

**Interfaces:**
- Consumes: `Bookmark.Kind.text`, `Bookmark.snippetBody` from Task 1.
- Produces: `LibraryDestination.snippets`, whose `accessibilityIdentifier` is `"library.snippets"`. Sidebar row identifier `"destination.snippets"`.

- [ ] **Step 1: Write the failing tests**

Append to `BookmarkCollectionsTests/LibraryFilteringTests.swift`, inside the existing class:

```swift
    func testSnippetsDestinationIncludesOnlyTextBookmarks() {
        let snippet = Bookmark(urlString: "", normalizedURLString: "")
        snippet.kind = .text
        snippet.snippetBody = "A saved paragraph"
        snippet.title = "A saved paragraph"

        let link = Bookmark(
            urlString: "https://example.com/story",
            normalizedURLString: "https://example.com/story"
        )

        let image = Bookmark(urlString: "", normalizedURLString: "")
        image.kind = .image

        XCTAssertTrue(LibraryDestination.snippets.includes(snippet))
        XCTAssertFalse(LibraryDestination.snippets.includes(link))
        XCTAssertFalse(LibraryDestination.snippets.includes(image))

        XCTAssertFalse(LibraryDestination.links.includes(snippet))
        XCTAssertFalse(LibraryDestination.images.includes(snippet))
        XCTAssertTrue(LibraryDestination.allItems.includes(snippet))
    }

    func testSnippetsDestinationExcludesDeletedSnippets() {
        let snippet = Bookmark(urlString: "", normalizedURLString: "")
        snippet.kind = .text
        snippet.snippetBody = "Deleted text"
        snippet.deletedAt = Date()

        XCTAssertFalse(LibraryDestination.snippets.includes(snippet))
        XCTAssertTrue(LibraryDestination.recentlyDeleted.includes(snippet))
    }

    func testSearchMatchesTextFoundOnlyInASnippetBody() {
        let snippet = Bookmark(urlString: "", normalizedURLString: "")
        snippet.kind = .text
        snippet.title = "Untitled note"
        snippet.snippetBody = "The migration runs on a Tuesday"

        XCTAssertTrue(
            LibraryDestination.allItems.matches(snippet, searchText: "tuesday")
        )
        XCTAssertFalse(
            LibraryDestination.allItems.matches(snippet, searchText: "wednesday")
        )
    }

    func testSnippetsDestinationIdentifierAndTitle() {
        XCTAssertEqual(LibraryDestination.snippets.title, "Snippets")
        XCTAssertEqual(LibraryDestination.snippets.accessibilityIdentifier, "library.snippets")
        XCTAssertEqual(LibraryDestination.snippets.systemImage, "text.quote")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/LibraryFilteringTests
```
Expected: compile failure — `type 'LibraryDestination' has no member 'snippets'`.

- [ ] **Step 3: Add the destination case**

In `BookmarkCollections/Features/Library/LibraryDestination.swift`, add `case snippets` after `case images`, then extend each switch. The compiler flags every non-exhaustive switch, so work through them:

```swift
enum LibraryDestination: Hashable {
    case allItems
    case favorites
    case links
    case images
    case snippets
    case collection(UUID)
    case forgotten
    case recentlyDeleted
```

`title`: `case .snippets: "Snippets"`
`systemImage`: `case .snippets: "text.quote"`
`accessibilityIdentifier`: `case .snippets: "library.snippets"`

`includes(_:)`:

```swift
        case .snippets:
            bookmark.deletedAt == nil && bookmark.kind == .text
```

`.links` and `.images` already filter on their own kinds, so they exclude snippets with no change.

- [ ] **Step 4: Add the snippet body to search**

In the same file, extend `matches(_:searchText:)`:

```swift
        return bookmark.title.localizedCaseInsensitiveContains(query)
            || bookmark.domain.localizedCaseInsensitiveContains(query)
            || bookmark.urlString.localizedCaseInsensitiveContains(query)
            || bookmark.snippetBody.localizedCaseInsensitiveContains(query)
            || (bookmark.collection?.name.localizedCaseInsensitiveContains(query) ?? false)
```

- [ ] **Step 5: Add the sidebar row**

In `BookmarkCollections/Features/Collections/CollectionListView.swift`, add the row inside `Section("Library")` after the Links row, so the order reads All Items, Images, Links, Snippets, Favorites, Forgotten:

```swift
                destinationRow(.links, title: "Links", identifier: "destination.links", showsCount: true)
                destinationRow(.snippets, title: "Snippets", identifier: "destination.snippets", showsCount: true)
                destinationRow(.favorites, title: "Favorites", identifier: "destination.favorites", showsCount: true)
```

The count badge comes from the existing `count(for:)` with no change.

- [ ] **Step 6: Run the tests to verify they pass**

Run:
```
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests
```
Expected: PASS.

- [ ] **Step 7: Build both schemes**

Run both commands from Global Constraints. Expected: BUILD SUCCEEDED for both.

- [ ] **Step 8: Commit**

```bash
git add BookmarkCollections/Features/Library/LibraryDestination.swift BookmarkCollections/Features/Collections/CollectionListView.swift BookmarkCollectionsTests/LibraryFilteringTests.swift
git commit -m "feat: add a Snippets sidebar destination and search snippet bodies

Snippets sit between Links and Favorites in the sidebar and carry a
count badge like every other destination. Search now matches the
snippet body, so a note with a generic title is still findable by what
it says.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Snippet editor, card excerpt, and open tracking

**Files:**
- Create: `BookmarkCollections/Features/Bookmark/SnippetEditorView.swift`
- Create: `BookmarkCollections/Features/Library/SnippetExcerpt.swift`
- Modify: `BookmarkCollections/Features/Library/BookmarkCard.swift`
- Modify: `BookmarkCollections/Features/Library/LibraryRootView.swift`
- Modify: `BookmarkCollections/Features/Library/LibraryToolbar.swift:42-50`
- Modify: `BookmarkCollections/Features/Bookmark/BookmarkActions.swift`
- Modify: `BookmarkCollections/Commands/BookmarkCommands.swift`
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift:52-88`
- Test: `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift`

**Interfaces:**
- Consumes: `BookmarkRepository.saveSnippet`, `.updateSnippet`, `.markOpened` from Task 1. `LibraryDestination.snippets` from Task 2.
- Produces:
  - `SnippetEditorView(bookmark: Bookmark?)` — `nil` creates, non-`nil` edits/views.
  - `SnippetExcerpt(text: String)`
  - `SheetDestination.snippetEditor(Bookmark?)`
  - `BookmarkCommandActions.newSnippet: () -> Void`
  - UI-test seed `bookmark.22222222-2222-2222-2222-222222222222`

- [ ] **Step 1: Write the failing UI test**

Add to `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift`:

```swift
    func testSnippetsDestinationShowsOnlyTextItems() {
        showSidebarIfNeeded()
        activate(destinationElement("destination.snippets"))

        let snippetCard = identified("bookmark.22222222-2222-2222-2222-222222222222")
        XCTAssertTrue(snippetCard.waitForExistence(timeout: 5))
        XCTAssertFalse(identified("bookmark.seeded-active").exists)
        XCTAssertFalse(identified("bookmark.11111111-1111-1111-1111-111111111111").exists)
    }
```

- [ ] **Step 2: Run the UI test to verify it fails**

Run:
```
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsUITests/BookmarkCollectionsUITests/testSnippetsDestinationShowsOnlyTextItems
```
Expected: FAIL — the `destination.snippets` row exists after Task 2, but no seeded snippet is in the library, so the card never appears.

If the whole macOS UI suite fails wholesale with element queries timing out, the runner's signature has gone stale. Run `scripts/reset-ui-tests.sh` and rerun from a clean rebuild. That is a signing problem, not a code problem.

- [ ] **Step 3: Seed a snippet for the UI suite**

In `BookmarkCollections/BookmarkCollectionsApp.swift`, inside `seedUITestLibrary`, add after the `image` block and before `try? context.save()`:

```swift
        let snippet = Bookmark(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            urlString: "",
            normalizedURLString: ""
        )
        snippet.kind = .text
        snippet.title = "Seeded Snippet"
        snippet.snippetBody = "The part of the article worth keeping, saved as text."
        snippet.metadataState = .ready
        context.insert(snippet)
```

- [ ] **Step 4: Create the snippet excerpt view**

Create `BookmarkCollections/Features/Library/SnippetExcerpt.swift`:

```swift
import SwiftUI

/// A snippet has no preview art, so its card shows the text instead.
struct SnippetExcerpt: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .background(.quaternary)
            .accessibilityHidden(true)
    }
}
```

- [ ] **Step 5: Show the excerpt on snippet cards**

In `BookmarkCollections/Features/Library/BookmarkCard.swift`, add a `.text` branch at the top of the `preview` builder, before the existing `if let previewImage`:

```swift
    @ViewBuilder
    private var preview: some View {
        if bookmark.kind == .text {
            SnippetExcerpt(text: bookmark.snippetBody)
        } else if let previewImage {
```

Then replace the `subtitle` computed property (`BookmarkCard.swift:107-111`) outright. It is currently a two-way ternary, which a third kind cannot be added to cleanly:

```swift
    private var subtitle: String {
        switch bookmark.kind {
        case .text:
            bookmark.domain.isEmpty ? "Snippet" : bookmark.domain
        case .image:
            bookmark.createdAt.formatted(date: .abbreviated, time: .omitted)
        case .link:
            bookmark.domain
        }
    }
```

A snippet with a source link shows that link's domain; one without shows `Snippet`.

`cardIdentifier` needs no change. It derives from `URL(string: bookmark.urlString)?.lastPathComponent` and falls back to the UUID, and `URL(string: "")` is nil — so a snippet's card identifier is `bookmark.<uuid>`, which is what the UI test in Step 1 queries.

- [ ] **Step 6: Create the snippet editor**

Create `BookmarkCollections/Features/Bookmark/SnippetEditorView.swift`:

```swift
import SwiftData
import SwiftUI

/// One surface for creating, editing, and reading a snippet. A snippet has
/// nowhere else to open, so the editor is also the viewer.
struct SnippetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \BookmarkCollection.sortPosition) private var collections: [BookmarkCollection]

    let bookmark: Bookmark?

    @State private var title = ""
    @State private var snippetBody = ""
    @State private var sourceURL = ""
    @State private var selectedCollectionID: UUID?
    @State private var isFavorite = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    TextEditor(text: $snippetBody)
                        .frame(minHeight: 140)
                        .accessibilityLabel("Snippet text")
                }
                Section {
                    TextField("Title", text: $title, prompt: Text("Optional"))
                    TextField(
                        "Source Link",
                        text: $sourceURL,
                        prompt: Text("Optional — where this came from")
                    )
                    .textContentType(.URL)
                    Picker("Collection", selection: $selectedCollectionID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(collections) { collection in
                            Text(collection.name).tag(collection.id as UUID?)
                        }
                    }
                    Toggle("Favorite", isOn: $isFavorite)
                }
                if let openableSource {
                    Button("Open Link", systemImage: "safari") { openURL(openableSource) }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(bookmark == nil ? "New Snippet" : "Snippet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(snippetBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
        .accessibilityIdentifier("snippet.editor")
        .onAppear(perform: load)
    }

    private var openableSource: URL? {
        guard !sourceURL.isEmpty else { return nil }
        return URL(string: sourceURL)
    }

    private func load() {
        guard let bookmark else { return }
        title = bookmark.title
        snippetBody = bookmark.snippetBody
        sourceURL = bookmark.urlString
        selectedCollectionID = bookmark.collection?.id
        isFavorite = bookmark.isFavorite
    }

    private func save() {
        let repository = BookmarkRepository(context: modelContext)
        let collection = collections.first { $0.id == selectedCollectionID }
        do {
            if let bookmark {
                try repository.updateSnippet(
                    bookmark,
                    title: title,
                    body: snippetBody,
                    sourceURL: sourceURL
                )
                try repository.move(bookmark, to: collection)
                try repository.setFavorite(bookmark, to: isFavorite)
            } else {
                try repository.saveSnippet(
                    title: title,
                    body: snippetBody,
                    sourceURL: sourceURL,
                    collection: collection,
                    favorite: isFavorite
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

Note the `#if os(macOS)` guard on `minWidth`. `BookmarkEditorView` applies its frame unconditionally, which the TODO already flags as a defect. Do not copy that mistake into a new file.

- [ ] **Step 7: Route snippets through the editor and mark them opened**

In `BookmarkCollections/Features/Library/LibraryRootView.swift`:

Add the sheet case to `SheetDestination`:

```swift
    case snippetEditor(Bookmark?)
```

and its id:

```swift
        case let .snippetEditor(bookmark): "snippet-\(bookmark?.id.uuidString ?? "new")"
```

Add the sheet content branch:

```swift
        case let .snippetEditor(bookmark):
            SnippetEditorView(bookmark: bookmark)
```

Extend `openBookmark` so opening a snippet counts as opening it. Without this a snippet read every week still falls into Forgotten after 30 days and can never leave:

```swift
    private func openBookmark(_ bookmark: Bookmark) {
        if bookmark.kind == .image {
            perform { try BookmarkRepository(context: modelContext).markOpened(bookmark) }
            sheet = .imageViewer(bookmark)
            return
        }
        if bookmark.kind == .text {
            perform { try BookmarkRepository(context: modelContext).markOpened(bookmark) }
            sheet = .snippetEditor(bookmark)
            return
        }
        guard let url = URL(string: bookmark.urlString), !bookmark.urlString.isEmpty else { return }
        perform { try BookmarkRepository(context: modelContext).markOpened(bookmark) }
        openURL(url)
    }
```

Route Edit for a snippet to the snippet editor rather than `BookmarkEditorView`. Find the `onEdit:` closure passed to the grid (around line 92) and change it:

```swift
                onEdit: { bookmark in
                    sheet = bookmark.kind == .text ? .snippetEditor(bookmark) : .editBookmark(bookmark)
                },
```

Add `newSnippet` to the `BookmarkCommandActions` construction (around line 223):

```swift
            newSnippet: { sheet = .snippetEditor(nil) },
```

Add the toolbar callback in the `LibraryToolbar` call (around line 105):

```swift
                    onNewSnippet: { sheet = .snippetEditor(nil) },
```

- [ ] **Step 8: Add New Snippet to the toolbar and menus**

In `BookmarkCollections/Features/Library/LibraryToolbar.swift`, add the property beside the existing callbacks:

```swift
    let onNewSnippet: () -> Void
```

and the menu item:

```swift
            Menu {
                Button("Add Link", systemImage: "link", action: onAdd)
                Button("New Snippet", systemImage: "text.quote", action: onNewSnippet)
                Button("New Collection", systemImage: "folder.badge.plus", action: onNewCollection)
                Divider()
                Button("Settings", systemImage: "gear", action: onSettings)
            } label: {
```

In `BookmarkCollections/Commands/BookmarkCommands.swift`, add the action to the struct:

```swift
    let newSnippet: () -> Void
```

and the command, in the `.newItem` group after Add Link:

```swift
            Button("New Snippet") { actions?.newSnippet() }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(actions == nil)
```

- [ ] **Step 9: Add Copy Text to the snippet context menu**

In `BookmarkCollections/Features/Bookmark/BookmarkActions.swift`, add the button in the non-deleted branch, after the Edit button:

```swift
            if bookmark.kind == .text {
                Button("Copy Text", systemImage: "doc.on.doc") {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bookmark.snippetBody, forType: .string)
                    #else
                    UIPasteboard.general.string = bookmark.snippetBody
                    #endif
                }
            }
```

The existing `ShareLink` branches are already gated on `.link` and `.image`, so a snippet correctly gets neither. Leave them alone.

- [ ] **Step 10: Run the UI test to verify it passes**

Run:
```
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsUITests
```
Expected: PASS, including the pre-existing UI tests.

- [ ] **Step 11: Build both schemes**

Run both commands from Global Constraints. Expected: BUILD SUCCEEDED for both.

- [ ] **Step 12: Commit**

```bash
git add BookmarkCollections BookmarkCollectionsUITests
git commit -m "feat: add the snippet editor, card excerpt, and open tracking

One view serves create, edit, and read. A snippet has nowhere else to
open, so opening one presents its editor — and that counts as opening
it. Without the markOpened call a snippet read every week would still
fall into Forgotten after 30 days with no way back out.

Cards show a text excerpt in place of preview art. Copy Text is on the
snippet context menu; New Snippet is on the toolbar menu and Command-T.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Backup snippets key

**Files:**
- Modify: `BookmarkCollections/Domain/BackupDocument.swift`
- Modify: `BookmarkCollections/Domain/LibraryExportService.swift`
- Modify: `BookmarkCollections/Domain/LibraryImportService.swift`
- Create: `BookmarkCollectionsTests/Fixtures/glaze-export.json`
- Test: `BookmarkCollectionsTests/ImportExportTests.swift`

**Interfaces:**
- Consumes: `BookmarkRepository.saveSnippet`, `.deriveSnippetTitle`, `.applySource` from Task 1.
- Produces: `BackupDocument.SnippetRecord`, `BackupDocument.snippets: [SnippetRecord]`.

**Note on the fixture:** the fixture below is hand-written to Glaze's exact output shape, taken from `/Users/geoffreysilva/Glaze/Tucked/sources/main/services/import-export.ts`. Check it in as written — do not regenerate it from a live Glaze export, because a live export would carry Geoff's real library.

- [ ] **Step 1: Create the Glaze export fixture**

Create `BookmarkCollectionsTests/Fixtures/glaze-export.json`. The synchronized file group copies it into the test bundle automatically. If `Bundle(for:).url(forResource:)` returns nil at Step 7, the file did not land as a resource — inline the same JSON as a multiline string constant in the test file, exactly as `testABackupWithoutASnippetsKeyStillImports` already does, rather than editing `project.pbxproj`.

```json
{
  "version": 1,
  "exportedAt": "2026-08-27T12:00:00.000Z",
  "collections": [
    {
      "id": "00000000-0000-0000-0000-0000000000A1",
      "name": "Reading",
      "sortPosition": 0,
      "createdAt": "2026-08-01T09:00:00.000Z",
      "modifiedAt": "2026-08-01T09:00:00.000Z"
    }
  ],
  "snippets": [
    {
      "id": "00000000-0000-0000-0000-0000000000B1",
      "title": "A kept paragraph",
      "body": "The part of the article worth keeping.\nAnd a second line.",
      "sourceUrl": "https://example.com/article",
      "isFavorite": true,
      "collectionID": "00000000-0000-0000-0000-0000000000A1",
      "createdAt": "2026-08-20T10:00:00.000Z",
      "modifiedAt": "2026-08-21T11:00:00.000Z",
      "deletedAt": null,
      "lastOpenedAt": null
    },
    {
      "id": "00000000-0000-0000-0000-0000000000B2",
      "title": "",
      "body": "   \nDerive my title from this line\ntrailing",
      "sourceUrl": null,
      "isFavorite": false,
      "collectionID": null,
      "createdAt": "2026-08-22T10:00:00.000Z",
      "modifiedAt": "2026-08-22T10:00:00.000Z",
      "deletedAt": null,
      "lastOpenedAt": null
    }
  ],
  "bookmarks": [
    {
      "id": "00000000-0000-0000-0000-0000000000C1",
      "urlString": "https://example.com/story",
      "normalizedURLString": "https://example.com/story",
      "title": "A Story",
      "domain": "example.com",
      "isFavorite": false,
      "collectionID": "00000000-0000-0000-0000-0000000000A1",
      "createdAt": "2026-08-19T10:00:00.000Z",
      "modifiedAt": "2026-08-19T10:00:00.000Z",
      "deletedAt": null,
      "lastOpenedAt": null
    }
  ]
}
```

- [ ] **Step 2: Write the failing tests**

Append to `BookmarkCollectionsTests/ImportExportTests.swift`, inside the existing class:

```swift
    func testImportingAGlazeExportRestoresSnippetsAlongsideLinks() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "glaze-export", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let service = LibraryImportService(context: container.mainContext)

        let summary = try service.importJSON(data)

        XCTAssertEqual(summary.newCount, 3)
        let bookmarks = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        let snippets = bookmarks.filter { $0.kind == .text }
        XCTAssertEqual(snippets.count, 2)

        let titled = try XCTUnwrap(snippets.first { $0.title == "A kept paragraph" })
        XCTAssertEqual(
            titled.snippetBody,
            "The part of the article worth keeping.\nAnd a second line."
        )
        XCTAssertEqual(titled.urlString, "https://example.com/article")
        XCTAssertEqual(titled.domain, "example.com")
        XCTAssertEqual(titled.normalizedURLString, "")
        XCTAssertTrue(titled.isFavorite)
        XCTAssertEqual(titled.collection?.name, "Reading")
        XCTAssertEqual(titled.metadataState, .ready)

        let derived = try XCTUnwrap(snippets.first { $0.title == "Derive my title from this line" })
        XCTAssertEqual(derived.urlString, "")
        XCTAssertEqual(derived.domain, "")
        XCTAssertNil(derived.collection)
    }

    func testImportingTheSameGlazeExportTwiceCreatesNoDuplicates() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "glaze-export", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let service = LibraryImportService(context: container.mainContext)
        _ = try service.importJSON(data)

        let summary = try service.importJSON(data)

        XCTAssertEqual(summary.newCount, 0)
        let snippets = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
            .filter { $0.kind == .text }
        XCTAssertEqual(snippets.count, 2)
        XCTAssertEqual(summary.duplicateCount, 3)
    }

    func testJSONRoundTripPreservesSnippets() throws {
        let source = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: source.mainContext)
        let collection = BookmarkCollection(name: "Research", sortPosition: 0)
        source.mainContext.insert(collection)
        let snippet = try repository.saveSnippet(
            title: "Kept",
            body: "Body text worth keeping",
            sourceURL: "https://example.com/source",
            collection: collection,
            favorite: true
        )
        let snippetID = snippet.id

        let data = try LibraryExportService(context: source.mainContext).exportJSON()

        let destination = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        _ = try LibraryImportService(context: destination.mainContext).importJSON(data)

        let restored = try XCTUnwrap(
            try destination.mainContext.fetch(FetchDescriptor<Bookmark>())
                .first { $0.id == snippetID }
        )
        XCTAssertEqual(restored.kind, .text)
        XCTAssertEqual(restored.snippetBody, "Body text worth keeping")
        XCTAssertEqual(restored.title, "Kept")
        XCTAssertEqual(restored.urlString, "https://example.com/source")
        XCTAssertTrue(restored.isFavorite)
        XCTAssertEqual(restored.collection?.name, "Research")
    }

    func testJSONExportKeepsSnippetsOutOfTheBookmarksArray() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        _ = try repository.save(url: "https://example.com/link")
        _ = try repository.saveSnippet(body: "Snippet text")

        let data = try LibraryExportService(context: container.mainContext).exportJSON()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(BackupDocument.self, from: data)

        XCTAssertEqual(document.bookmarks.count, 1)
        XCTAssertEqual(document.bookmarks.first?.urlString, "https://example.com/link")
        XCTAssertEqual(document.snippets.count, 1)
        XCTAssertEqual(document.snippets.first?.body, "Snippet text")
    }

    func testHTMLExportOmitsSnippets() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        _ = try repository.save(url: "https://example.com/link")
        _ = try repository.saveSnippet(body: "Snippet text that must not ship")

        let data = try LibraryExportService(context: container.mainContext).exportHTML()
        let html = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(html.contains("https://example.com/link"))
        XCTAssertFalse(html.contains("Snippet text that must not ship"))
    }

    func testABackupWithoutASnippetsKeyStillImports() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let legacy = """
        {
          "version": 1,
          "exportedAt": "2026-08-01T09:00:00Z",
          "collections": [],
          "bookmarks": [
            {
              "id": "00000000-0000-0000-0000-0000000000D1",
              "urlString": "https://example.com/legacy",
              "normalizedURLString": "https://example.com/legacy",
              "title": "Legacy",
              "domain": "example.com",
              "isFavorite": false,
              "collectionID": null,
              "createdAt": "2026-08-01T09:00:00Z",
              "modifiedAt": "2026-08-01T09:00:00Z",
              "deletedAt": null,
              "lastOpenedAt": null
            }
          ]
        }
        """
        let service = LibraryImportService(context: container.mainContext)

        let summary = try service.importJSON(Data(legacy.utf8))

        XCTAssertEqual(summary.newCount, 1)
        XCTAssertEqual(
            try container.mainContext.fetch(FetchDescriptor<Bookmark>()).count,
            1
        )
    }
```

- [ ] **Step 3: Run the tests to verify they fail**

Run:
```
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/ImportExportTests
```
Expected: compile failure — `value of type 'BackupDocument' has no member 'snippets'`.

- [ ] **Step 4: Add the snippet record to the backup document**

In `BookmarkCollections/Domain/BackupDocument.swift`, add `snippets` to the struct, its initializer, and a new record type. `snippets` decodes with `decodeIfPresent` so every backup written before this change still restores:

```swift
struct BackupDocument: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let collections: [CollectionRecord]
    let bookmarks: [BookmarkRecord]
    let snippets: [SnippetRecord]

    init(
        version: Int = currentVersion,
        exportedAt: Date,
        collections: [CollectionRecord],
        bookmarks: [BookmarkRecord],
        snippets: [SnippetRecord] = []
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.collections = collections
        self.bookmarks = bookmarks
        self.snippets = snippets
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        collections = try container.decodeIfPresent([CollectionRecord].self, forKey: .collections) ?? []
        bookmarks = try container.decodeIfPresent([BookmarkRecord].self, forKey: .bookmarks) ?? []
        snippets = try container.decodeIfPresent([SnippetRecord].self, forKey: .snippets) ?? []
    }
```

Add the record type beside `BookmarkRecord`. Key names match the Glaze writer exactly, including the lower-camel `sourceUrl` against the upper-case `collectionID` — that inconsistency is Glaze's, and matching it is the point:

```swift
    struct SnippetRecord: Codable, Sendable {
        let id: UUID
        let title: String
        let body: String
        let sourceUrl: String?
        let isFavorite: Bool
        let collectionID: UUID?
        let createdAt: Date
        let modifiedAt: Date
        let deletedAt: Date?
        let lastOpenedAt: Date?
    }
```

- [ ] **Step 5: Export snippets under their own key**

In `BookmarkCollections/Domain/LibraryExportService.swift`, change the bookmark filter and add the snippets array.

The current filter is `kind != .image`. Once `.text` exists that filter lets snippets into the `bookmarks` array as URL-less links, which the Glaze importer rejects and the Swift importer mangles. Change it:

```swift
        let allBookmarks = try context.fetch(
            FetchDescriptor<Bookmark>(sortBy: [
                SortDescriptor(\Bookmark.createdAt),
                SortDescriptor(\Bookmark.id)
            ])
        )
        let bookmarks = allBookmarks.filter { $0.kind == .link }
        let snippets = allBookmarks.filter { $0.kind == .text }
```

Then pass the mapped snippets to the document initializer:

```swift
            snippets: snippets.map { snippet in
                BackupDocument.SnippetRecord(
                    id: snippet.id,
                    title: snippet.title,
                    body: snippet.snippetBody,
                    sourceUrl: snippet.urlString.isEmpty ? nil : snippet.urlString,
                    isFavorite: snippet.isFavorite,
                    collectionID: snippet.collection?.id,
                    createdAt: snippet.createdAt,
                    modifiedAt: snippet.modifiedAt,
                    deletedAt: snippet.deletedAt,
                    lastOpenedAt: snippet.lastOpenedAt
                )
            }
```

Check `exportHTML` in the same file. It must filter to `kind == .link`. If it filters on `kind != .image`, change it to `kind == .link` for the same reason.

- [ ] **Step 6: Import the snippets array**

In `BookmarkCollections/Domain/LibraryImportService.swift`, add the snippet loop **after the existing bookmark loop and immediately before `try context.save()`** — not before `return summary`, because `try context.save()` and `reconcileDuplicates()` sit between the two, and a snippet inserted after the save would never persist.

Reuse the `bookmarksByID` dictionary the bookmark loop already built rather than issuing a fresh fetch. The dictionary is authoritative for this transaction, and a fetch would depend on SwiftData surfacing unsaved inserts.

Snippets are matched on `id` alone and never touch normalized-URL de-duplication:

```swift
        for record in document.snippets {
            let body = record.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }

            let existing = bookmarksByID[record.id]

            if existing == nil {
                summary.newCount += 1
            } else {
                summary.duplicateCount += 1
            }

            let snippet = existing ?? Bookmark(
                id: record.id,
                urlString: "",
                normalizedURLString: "",
                createdAt: record.createdAt,
                modifiedAt: record.modifiedAt
            )
            snippet.kind = .text
            snippet.snippetBody = body
            snippet.title = BookmarkRepository.deriveSnippetTitle(record.title, body: body)
            // Glaze writes no domain for a snippet, so the host is always
            // derived from the source link here, never read from the backup.
            BookmarkRepository.applySource(record.sourceUrl, to: snippet)
            snippet.normalizedURLString = ""
            snippet.isFavorite = record.isFavorite
            snippet.collection = record.collectionID.flatMap { collectionsByID[$0] }
            snippet.createdAt = record.createdAt
            snippet.modifiedAt = record.modifiedAt
            snippet.deletedAt = record.deletedAt
            snippet.lastOpenedAt = record.lastOpenedAt
            snippet.metadataState = .ready

            if existing == nil {
                context.insert(snippet)
                bookmarksByID[record.id] = snippet
            }
        }
```

Two snippet records carrying the same id inside one backup therefore collapse to one record, exactly as two bookmark records with the same id already do.

`Bookmark.init` already accepts an id: `init(id:urlString:normalizedURLString:createdAt:modifiedAt:)`, with `id` defaulted. Passing `record.id` is what preserves identity across a round trip, and it is also what makes the second import of the same file a duplicate rather than a second copy.

- [ ] **Step 7: Run the tests to verify they pass**

Run:
```
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests
```
Expected: PASS, including the pre-existing `testJSONRoundTripPreservesUserDataAndOrganization`.

- [ ] **Step 8: Build both schemes**

Run both commands from Global Constraints. Expected: BUILD SUCCEEDED for both.

- [ ] **Step 9: Commit**

```bash
git add BookmarkCollections/Domain BookmarkCollectionsTests
git commit -m "feat: read and write snippets in the JSON backup format

Glaze already writes snippets into the Swift-compatible backup under a
top-level snippets key, and the Swift decoder dropped them silently.
That made every snippet in the Glaze library unreachable from here.
The decoder now reads that key, so a Glaze export is the migration path.

Also fixes a latent export bug the new kind would have exposed: the
bookmarks array filtered on kind != .image, so a snippet would have
shipped as a URL-less link. It now filters on kind == .link.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Add Images on macOS

**Files:**
- Modify: `BookmarkCollections/Commands/BookmarkCommands.swift`
- Modify: `BookmarkCollections/Features/Library/LibraryRootView.swift`
- Modify: `BookmarkCollections/Features/Library/LibraryToolbar.swift`
- Create: `BookmarkCollections/Domain/ImageImportService.swift`
- Test: `BookmarkCollectionsTests/ImageImportTests.swift` (create)

**Interfaces:**
- Consumes: `ImageDownsampler.isValidImage(_:) -> Bool`, `ImageDownsampler.downsample(_:maximumPixelSize:) -> Data`, `BookmarkRepository.saveImage(data:title:collection:favorite:)`.
- Produces: `ImageImportService.importImages(at:) throws -> ImportSummary` in `BookmarkCollections/Domain/ImageImportService.swift` (create).

**Why a service rather than inline `.fileImporter` handling:** the file-picker result is untestable, but the read-downsample-save loop is not. Putting the loop in a service means the batch behavior — one unreadable file must not cost the rest of the selection — is covered by a unit test.

- [ ] **Step 1: Write the failing tests**

Create `BookmarkCollectionsTests/ImageImportTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class ImageImportTests: XCTestCase {
    func testImportingImageFilesSavesDownsampledImageBookmarks() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appendingPathComponent("Screenshot One.png")
        try Self.pngData(width: 40, height: 30).write(to: first)
        let second = directory.appendingPathComponent("Screenshot Two.png")
        try Self.pngData(width: 20, height: 20).write(to: second)

        let service = ImageImportService(context: container.mainContext)
        let summary = try service.importImages(at: [first, second])

        XCTAssertEqual(summary.newCount, 2)
        XCTAssertTrue(summary.failedLines.isEmpty)

        let bookmarks = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(bookmarks.count, 2)
        XCTAssertTrue(bookmarks.allSatisfy { $0.kind == .image })
        XCTAssertTrue(bookmarks.allSatisfy { $0.previewImageData != nil })
        XCTAssertTrue(bookmarks.allSatisfy { $0.collection == nil })
        XCTAssertTrue(bookmarks.allSatisfy { !$0.isFavorite })
        XCTAssertEqual(
            Set(bookmarks.map(\.title)),
            ["Screenshot One", "Screenshot Two"]
        )
    }

    func testOneUnreadableFileDoesNotCostTheRestOfTheBatch() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let good = directory.appendingPathComponent("Good.png")
        try Self.pngData(width: 40, height: 30).write(to: good)
        let bad = directory.appendingPathComponent("Bad.png")
        try Data("not an image".utf8).write(to: bad)

        let service = ImageImportService(context: container.mainContext)
        let summary = try service.importImages(at: [good, bad])

        XCTAssertEqual(summary.newCount, 1)
        XCTAssertEqual(summary.failedLines, ["Bad.png"])
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Bookmark>()).count, 1)
    }

    /// A minimal opaque PNG, built through the platform image encoder so the
    /// bytes are whatever ImageDownsampler actually accepts.
    private static func pngData(width: Int, height: Int) throws -> Data {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())

        let output = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
```

Add `import CoreGraphics` and `import ImageIO` at the top of the file if the build reports the symbols as unavailable.

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/ImageImportTests
```
Expected: compile failure — `cannot find 'ImageImportService' in scope`.

- [ ] **Step 3: Create the import service**

Create `BookmarkCollections/Domain/ImageImportService.swift`:

```swift
import Foundation
import SwiftData

/// Reads image files chosen from a file picker and saves them through the
/// same downsample-and-store path the Share extension uses.
@MainActor
struct ImageImportService {
    let context: ModelContext

    /// One unreadable file must not cost the rest of the selection, so a
    /// failure is recorded and the batch continues.
    func importImages(at urls: [URL]) throws -> ImportSummary {
        let repository = BookmarkRepository(context: context)
        var summary = ImportSummary()

        for url in urls {
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url), ImageDownsampler.isValidImage(data) else {
                summary.failedLines.append(url.lastPathComponent)
                continue
            }

            do {
                try repository.saveImage(
                    data: ImageDownsampler.downsample(data, maximumPixelSize: 1_200),
                    title: url.deletingPathExtension().lastPathComponent
                )
                summary.newCount += 1
            } catch {
                summary.failedLines.append(url.lastPathComponent)
            }
        }

        return summary
    }
}
```

`1_200` is the same maximum pixel size the Share extension uses in `ShareCaptureModel.swift:223`. Keep the two in step.

- [ ] **Step 4: Add the file importer to the library**

In `BookmarkCollections/Features/Library/LibraryRootView.swift`, add state beside the existing `@State` properties:

```swift
    #if os(macOS)
    @State private var isAddingImages = false
    #endif
```

This one is legal: `#if` around a property *declaration* is fine. It is only argument lists that cannot be guarded.

Attach the importer to the same view that carries `.sheet(item: $sheet, ...)`:

```swift
        #if os(macOS)
        .fileImporter(
            isPresented: $isAddingImages,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                perform {
                    let summary = try ImageImportService(context: modelContext).importImages(at: urls)
                    if !summary.failedLines.isEmpty {
                        errorMessage = "Could not add \(summary.failedLines.count) of \(urls.count) images."
                    }
                }
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
        #endif
```

Add `import UniformTypeIdentifiers` at the top of the file for `.image`.

Wire the action into the `BookmarkCommandActions` construction (around line 223) and the `LibraryToolbar` call (around line 105). Both arguments are passed unconditionally — see the Global Constraint above, `#if` cannot wrap a labeled argument:

```swift
            addImages: addImages,
```

```swift
                    onAddImages: addImages,
```

and add the single platform-guarded helper beside the other private methods:

```swift
    private func addImages() {
        #if os(macOS)
        isAddingImages = true
        #endif
    }
```

On iOS this compiles to an empty method that nothing calls, because the menu item and toolbar button that would call it are themselves guarded out.

- [ ] **Step 5: Add the menu and toolbar entries**

In `BookmarkCollections/Commands/BookmarkCommands.swift`, add the action to the struct unconditionally, and guard only the command itself:

```swift
    let addImages: () -> Void
```

```swift
            #if os(macOS)
            Button("Add Images…") { actions?.addImages() }
                .disabled(actions == nil)
            #endif
```

`BookmarkCommands` is only installed on macOS, but `BookmarkCommandActions` is constructed on every platform, so the property must exist everywhere.

In `BookmarkCollections/Features/Library/LibraryToolbar.swift`, add the property unconditionally and guard only the menu item:

```swift
    let onAddImages: () -> Void
```

```swift
                Button("New Snippet", systemImage: "text.quote", action: onNewSnippet)
                #if os(macOS)
                Button("Add Images…", systemImage: "photo.badge.plus", action: onAddImages)
                #endif
                Button("New Collection", systemImage: "folder.badge.plus", action: onNewCollection)
```

- [ ] **Step 6: Run the tests to verify they pass**

Run:
```
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests
```
Expected: PASS.

- [ ] **Step 7: Build both schemes**

Run both commands from Global Constraints. The iOS builds are the ones that prove the `#if os(macOS)` guards are placed correctly — a misplaced guard breaks the iOS build while macOS stays green. Expected: BUILD SUCCEEDED for both.

- [ ] **Step 8: Commit**

```bash
git add BookmarkCollections BookmarkCollectionsTests/ImageImportTests.swift
git commit -m "feat: add File > Add Images on macOS

Images can now be added from a file picker rather than only through the
Share menu. Files route through the existing ImageDownsampler and
saveImage, so there is no second image path.

The read-downsample-save loop lives in a service rather than inline in
the fileImporter callback, which is what makes the batch behavior
testable: one unreadable file is recorded and skipped, and the rest of
the selection still lands.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Device verification and documentation

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `TODO.md`
- Modify: `DECISIONS.md`
- Modify: `README.md`

- [ ] **Step 1: Install and verify on the Mac**

```bash
scripts/install-mac.sh
```

Then check by hand, in order:

1. Sidebar shows **Snippets** between Links and Favorites, with a count badge.
2. Toolbar "+" ▸ **New Snippet** opens the editor. Save is disabled until text is typed.
3. Save a snippet with no title. The card title is the first line of the body.
4. The card shows a text excerpt, not empty preview art.
5. ⌘T opens a new snippet.
6. Right-click a snippet ▸ **Copy Text**. Paste elsewhere and confirm the body.
7. Open the snippet. It presents the editor, and Get Info shows a Last Opened date.
8. Search for a word that appears only in a snippet body. The snippet is found.
9. **File ▸ Add Images…**, select two images. Both appear under Images.
10. Settings ▸ Export JSON, then Import JSON into a fresh install. Snippets survive.

Report any step that fails before continuing. Do not update docs for behavior that was not seen working.

- [ ] **Step 2: Verify the real Glaze migration**

This is the point of the whole change, so verify it against the real library rather than the fixture:

1. In the Glaze app at `/Applications/Glaze/Tucked.app`, export JSON.
2. In Tucked, Settings ▸ Import JSON, choosing that file.
3. Confirm the snippet count matches and spot-check three snippets for body, source link, collection, and favorite state.

- [ ] **Step 3: Update CHANGELOG.md**

Add to the `## 1.0.0 — Unreleased` section under `### Added`, keeping the existing entry style:

```markdown
- Text snippets: a third bookmark kind holding a piece of text with an optional source link, its own Snippets sidebar destination, a text-excerpt card, and Copy Text. Search matches snippet bodies.
- JSON backup carries snippets under a `snippets` key, so libraries move between the Swift app and the Glaze build in both directions.
- `File ▸ Add Images…` on macOS adds images from a file picker rather than only through the Share menu.
```

- [ ] **Step 4: Update TODO.md**

Check off the completed backlog item and move it to Done with today's date:

```markdown
- [x] Files-importer image import (Mac) — shipped as `File ▸ Add Images…` (2026-08-28).
```

Remove `- Files-importer image import (Mac).` from Backlog.

Add to Backlog, since the new kind widens two existing items:

```markdown
- Make macOS menu commands kind-aware for snippets as well as images. Open and Share both assume a URL.
- Sharing plain non-URL text from the iOS Share Sheet to create a snippet. Deliberately out of scope in the 2026-08-28 parity pass; snippets are created in-app only.
- Mac quick-capture panel with a global shortcut and clipboard detection, as in the Glaze build. Out of scope in the 2026-08-28 parity pass because macOS already captures through the Share menu.
```

- [ ] **Step 5: Update DECISIONS.md**

Append a new entry in the existing format:

```markdown
## 2026-08-28 (Snippets reuse the bookmark model rather than getting their own)

**Decision** — A snippet is a `Bookmark` with `kind == .text`, a `snippetBody`,
and an empty `normalizedURLString`. It is not a separate SwiftData model.

**Why** — Every library behavior a snippet needs already exists on `Bookmark`:
collections, Favorite, soft delete, Recently Deleted, Forgotten, search,
sorting, and CloudKit mirroring. A second model would have had to reimplement
all of it and then be merged back at every destination. The empty normalized
URL is what keeps snippets out of link de-duplication, and image bookmarks
already rely on the same trick.

**Alternative considered** — A separate `Snippet` model with its own repository.
Rejected: it doubles every destination, every sort, and every backup path for
one differing field.

## 2026-08-28 (Opening a snippet opens its editor, and that counts as opening it)

**Decision** — Opening a snippet presents `SnippetEditorView` and calls
`markOpened`.

**Why** — A snippet has nowhere else to open. Making the editor the viewer
avoids a read-only surface that duplicates the editor's layout. The
`markOpened` call is not cosmetic: without it, a snippet read every week still
falls into Forgotten after 30 days and can never leave, because Forgotten keys
on `lastOpenedAt` being nil.

**Alternative considered** — A separate read-only snippet viewer, matching
`ImageViewerView`. Rejected: an image viewer earns its own surface because
zoom and full-screen are not editing affordances. Text has no equivalent.
```

- [ ] **Step 6: Update README.md**

In the opening paragraph, add snippets to the list of what the app captures and organizes, and add Snippets to the sidebar destinations sentence. In the Import and export section, add a line under the Settings list:

```markdown
- Versioned JSON backup and restore, preserving UUIDs, titles, collections/order, favorites, dates, and text snippets.
```

- [ ] **Step 7: Commit**

```bash
git add CHANGELOG.md TODO.md DECISIONS.md README.md
git commit -m "docs: record the snippets and Add Images work

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 8: Request review**

Use the `superpowers:requesting-code-review` skill against the full branch diff before merging. Do not merge to `main` — Geoff handles the push.

---

## Notes for the executor

**Things that will bite you:**

1. **App-only builds lie.** `Bookmark.swift` and `BookmarkRepository.swift` compile into the share extension. Build both schemes after every task, not just at the end.
2. **`Kind` is no longer a two-case switch.** Adding `.text` makes several `switch` statements non-exhaustive and several `if kind == .link / else` branches wrong by omission. Read every `kind ==` comparison the compiler does *not* flag — `BookmarkActions.swift` and `LibraryRootView.openBookmark` both have them.
3. **`URL(string: "")` is nil.** A snippet with no source link has an empty `urlString`. Any code path that force-unwraps a URL from a bookmark will crash on a snippet. `BookmarkActions` has `ShareLink(item: URL(string: bookmark.urlString)!)` gated behind `kind == .link` — that gate is what keeps it safe. Do not widen it.
4. **The macOS UI runner must stay code signed.** If the whole UI suite starts failing with element queries timing out on known-good code, the runner's signature is stale. Run `scripts/reset-ui-tests.sh`.
5. **Do not add `-quiet` to xcodebuild.** Error parsing needs the surrounding context to find the first real error.
