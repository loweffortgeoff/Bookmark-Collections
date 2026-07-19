# Sidebar Count Totals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show trailing item counts on library sidebar destinations (All Items, Images, Links, Favorites) and each collection row, always including zero; leave Recently Deleted without a count.

**Architecture:** Add a pure count helper on `LibraryDestination` that filters via existing `includes(_:)`. `CollectionListView` queries bookmarks and displays secondary trailing counts on counted rows. No model/schema changes.

**Tech Stack:** SwiftUI, SwiftData, XCTest. No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-07-19-sidebar-count-totals-design.md`

## Global Constraints

- Swift 6, iOS 18+, macOS 15+, Xcode 26.6+ (README floor).
- No third-party dependencies. SwiftUI / SwiftData only.
- Match existing code style exactly; no drive-by refactors.
- Counts must use `LibraryDestination.includes` — do not duplicate filter predicates in the view.
- Always show numeric counts including `0` on library destinations and collections; never show a count on Recently Deleted.
- All work on branch `feature/sidebar-count-totals` (create from `main` before Task 1; use a worktree per superpowers:using-git-worktrees if executing with subagents).
- Unit test command (expected `** TEST SUCCEEDED **`):
  ```bash
  xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections \
    -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests
  ```
- New UI: system secondary label for counts; Dynamic Type via system text styles; light+dark via system styles.

## File map

| File | Role |
|------|------|
| `BookmarkCollections/Features/Library/LibraryDestination.swift` | Add `count(in:)` helper using `includes` |
| `BookmarkCollections/Features/Collections/CollectionListView.swift` | Query bookmarks; trailing counts on library + collection rows |
| `BookmarkCollectionsTests/LibraryFilteringTests.swift` | Unit tests for counts |
| `CHANGELOG.md` | Note the sidebar counts feature (end of Task 2) |

---

### Task 1: Count helper + unit tests

**Files:**
- Modify: `BookmarkCollections/Features/Library/LibraryDestination.swift`
- Modify: `BookmarkCollectionsTests/LibraryFilteringTests.swift`

**Interfaces:**
- Consumes: existing `LibraryDestination.includes(_: Bookmark) -> Bool`
- Produces: `LibraryDestination.count(in bookmarks: [Bookmark]) -> Int` — instance method returning `bookmarks.filter { includes($0) }.count`

- [x] **Step 1: Create the feature branch**

```bash
git checkout main
git pull --ff-only
git checkout -b feature/sidebar-count-totals
```

- [x] **Step 2: Write the failing unit test**

Append to `LibraryFilteringTests` (after `testLinksDestinationExcludesImageKind`, before `makeBookmark`):

```swift
    func testDestinationCountsMatchInclusionRules() {
        let development = BookmarkCollection(name: "Development", sortPosition: 0)
        let research = BookmarkCollection(name: "Research", sortPosition: 1)

        let activeLink = makeBookmark(path: "active-link")
        let favoriteLink = makeBookmark(path: "favorite-link", favorite: true)
        let filedLink = makeBookmark(path: "filed-link", collection: development)
        let image = makeBookmark(path: "image")
        image.kind = .image
        let favoriteImage = makeBookmark(path: "favorite-image", favorite: true, collection: research)
        favoriteImage.kind = .image
        let deletedLink = makeBookmark(path: "deleted-link", deletedAt: Date())
        let deletedInCollection = makeBookmark(path: "deleted-filed", collection: development, deletedAt: Date())

        let bookmarks = [
            activeLink, favoriteLink, filedLink, image, favoriteImage, deletedLink, deletedInCollection
        ]

        XCTAssertEqual(LibraryDestination.allItems.count(in: bookmarks), 5)
        XCTAssertEqual(LibraryDestination.links.count(in: bookmarks), 3)
        XCTAssertEqual(LibraryDestination.images.count(in: bookmarks), 2)
        XCTAssertEqual(LibraryDestination.favorites.count(in: bookmarks), 2)
        XCTAssertEqual(LibraryDestination.collection(development.id).count(in: bookmarks), 1)
        XCTAssertEqual(LibraryDestination.collection(research.id).count(in: bookmarks), 1)
        XCTAssertEqual(LibraryDestination.collection(UUID()).count(in: bookmarks), 0)
        XCTAssertEqual(LibraryDestination.recentlyDeleted.count(in: bookmarks), 2)
        XCTAssertEqual(LibraryDestination.allItems.count(in: []), 0)
    }
```

Notes on expected numbers:
- Active (non-deleted): activeLink, favoriteLink, filedLink, image, favoriteImage → **5** All Items
- Links among active: activeLink, favoriteLink, filedLink → **3** (images excluded)
- Images among active: image, favoriteImage → **2**
- Favorites among active: favoriteLink, favoriteImage → **2**
- Development collection active: filedLink only (deletedInCollection excluded) → **1**
- Research collection active: favoriteImage → **1**
- Soft-deleted: deletedLink, deletedInCollection → **2** Recently Deleted (helper is correct even though UI will not display this count)

- [x] **Step 3: Run the test to verify it fails**

```bash
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests/LibraryFilteringTests/testDestinationCountsMatchInclusionRules
```

Expected: FAIL — `count(in:)` does not exist on `LibraryDestination`.

- [x] **Step 4: Implement the minimal helper**

In `LibraryDestination.swift`, after `includes(_ bookmark: Bookmark) -> Bool` (before `matches`), add:

```swift
    func count(in bookmarks: [Bookmark]) -> Int {
        bookmarks.filter { includes($0) }.count
    }
```

Do not add any other filter logic. The method must only call `includes`.

- [x] **Step 5: Run the test to verify it passes**

```bash
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests/LibraryFilteringTests
```

Expected: `** TEST SUCCEEDED **` (all `LibraryFilteringTests` green).

- [x] **Step 6: Commit**

```bash
git add \
  BookmarkCollections/Features/Library/LibraryDestination.swift \
  BookmarkCollectionsTests/LibraryFilteringTests.swift
git commit -m "$(cat <<'EOF'
feat: add LibraryDestination.count helper for sidebar totals

Counts reuse includes() so filter and badge stay aligned.
EOF
)"
```

---

### Task 2: Sidebar trailing counts UI

**Files:**
- Modify: `BookmarkCollections/Features/Collections/CollectionListView.swift`
- Modify: `CHANGELOG.md` (Unreleased / Added bullet)

**Interfaces:**
- Consumes: `LibraryDestination.count(in:)` from Task 1; SwiftData `@Query` for `[Bookmark]`
- Produces: Trailing secondary count on All Items, Images, Links, Favorites, and each collection row; Recently Deleted unchanged (no count)

- [x] **Step 1: Add bookmark query and count helper to CollectionListView**

In `CollectionListView.swift`, add a second `@Query` after the existing collections query:

```swift
    @Query(sort: [SortDescriptor(\Bookmark.createdAt), SortDescriptor(\Bookmark.id)])
    private var bookmarks: [Bookmark]
```

Add a private helper on the view (after `body` / near `destinationRow`):

```swift
    private func count(for destination: LibraryDestination) -> Int {
        destination.count(in: bookmarks)
    }
```

- [x] **Step 2: Update destinationRow to show optional trailing count**

Replace `destinationRow` and its call sites so library destinations show counts and Recently Deleted does not.

Replace the entire `destinationRow` method with:

```swift
    private func destinationRow(
        _ destination: LibraryDestination,
        title: String,
        identifier: String,
        showsCount: Bool
    ) -> some View {
        NavigationLink(value: destination) {
            HStack {
                Label(title, systemImage: destination.systemImage)
                if showsCount {
                    Spacer()
                    Text("\(count(for: destination))")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(count(for: destination)) items")
                }
            }
        }
        .tag(destination)
        .accessibilityIdentifier(identifier)
    }
```

Update Library section call sites to pass `showsCount: true`:

```swift
            Section("Library") {
                destinationRow(.allItems, title: "All Items", identifier: "destination.allItems", showsCount: true)
                destinationRow(.images, title: "Images", identifier: "destination.images", showsCount: true)
                destinationRow(.links, title: "Links", identifier: "destination.links", showsCount: true)
                destinationRow(.favorites, title: "Favorites", identifier: "destination.favorites", showsCount: true)
            }
```

Update Recently Deleted call site to pass `showsCount: false`:

```swift
            Section {
                destinationRow(
                    .recentlyDeleted,
                    title: "Recently Deleted",
                    identifier: "destination.recentlyDeleted",
                    showsCount: false
                )
            }
```

- [x] **Step 3: Add counts to collection rows**

Replace the collection `ForEach` label body so each collection row shows a trailing count. Keep context menu, tag, and accessibility identifiers as they are today.

```swift
                    ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                        let destination = LibraryDestination.collection(collection.id)
                        NavigationLink(value: destination) {
                            HStack {
                                Label(collection.name, systemImage: "folder")
                                Spacer()
                                Text("\(count(for: destination))")
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("\(count(for: destination)) items")
                            }
                            .contextMenu {
                                Button("Rename") { onEdit(collection) }
                                Button("Delete", role: .destructive) { onDelete(collection) }
                            }
                        }
                        .tag(destination)
                        .accessibilityIdentifier(index == 0 ? "destination.collections" : "destination.collection.\(collection.id)")
                    }
```

Note: `contextMenu` stays on the label content (as today on `Label`); do not remove rename/delete.

- [x] **Step 4: Build to verify compile**

```bash
xcodebuild build -project BookmarkCollections.xcodeproj -scheme BookmarkCollections \
  -destination 'platform=macOS'
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 5: Re-run unit tests**

```bash
xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections \
  -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests
```

Expected: `** TEST SUCCEEDED **`

- [x] **Step 6: Manual smoke (local simulator or Mac app)**

Confirm visually:
1. Empty library → All Items / Images / Links / Favorites show `0`
2. Add a link → All Items and Links increment; Images stays `0` if no images
3. Favorite a bookmark → Favorites increments
4. Assign to a collection → that collection’s count increments
5. Soft-delete → library/collection counts drop; Recently Deleted still has no trailing number

- [x] **Step 7: Changelog**

Under `CHANGELOG.md` Unreleased → Added (create Unreleased section if missing), add:

```markdown
- Sidebar shows item counts for All Items, Images, Links, Favorites, and each collection.
```

- [x] **Step 8: Commit**

```bash
git add \
  BookmarkCollections/Features/Collections/CollectionListView.swift \
  CHANGELOG.md
git commit -m "$(cat <<'EOF'
feat: show sidebar counts for library destinations and collections

Trailing secondary totals reuse LibraryDestination.count; Recently Deleted stays uncounted.
EOF
)"
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| All Items / Images / Links / Favorites counts | Task 2 |
| Collection row counts | Task 2 |
| Always show including 0 | Task 2 (`Text("\(count)")` always when `showsCount`) |
| No count on Recently Deleted | Task 2 (`showsCount: false`) |
| Reuse `includes` / no parallel filters | Task 1 helper |
| Soft-deleted excluded from library/collection | Task 1 tests + `includes` |
| Unit tests for fixture counts | Task 1 |
| No schema / CloudKit | No model tasks |
| Branch off main | Task 1 Step 1 |

No placeholders. Interfaces consistent: `count(in:)` used by tests and `CollectionListView.count(for:)`.
