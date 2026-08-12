# Native System Accent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the in-app accent picker and custom sidebar pills so tint and selection come from the system.

**Architecture:** Delete `AppAccent` and `AccentPickerView`, stop applying a root `.tint`, and delete the compiled Grape `AccentColor` asset plus its `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` build setting. Restore `CollectionListView` to tagged `Label` rows inside `List(selection:)` with `.badge` counts. Features is a synchronized Xcode group, so deleting Swift files needs no file-ref edits.

**Tech Stack:** SwiftUI, Swift 6, XCTest / XCUITest, Xcode synchronized root groups. No third-party libraries.

**Spec:** `docs/superpowers/specs/2026-08-12-native-system-accent-design.md`

## File Structure

| File | Role |
| --- | --- |
| `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift` | Sidebar and Settings UI coverage. `destinationElement` must find native list rows, not only buttons. |
| `BookmarkCollections/Features/Collections/CollectionListView.swift` | Sidebar. Replace custom `SidebarRow` with tagged `Label`s. |
| `BookmarkCollections/Features/Settings/SettingsView.swift` | Drop the Appearance section and accent sheet. |
| `BookmarkCollections/BookmarkCollectionsApp.swift` | Drop `@AppStorage` accent key and root `.tint`. |
| `BookmarkCollections/Features/Appearance/AppAccent.swift` | Delete. |
| `BookmarkCollections/Features/Appearance/AccentPickerView.swift` | Delete. |
| `BookmarkCollections/Assets.xcassets/AccentColor.colorset/` | Delete (Grape pair). |
| `BookmarkCollections.xcodeproj/project.pbxproj` | Delete `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` on the app target Debug and Release configs. |
| `README.md`, `CHANGELOG.md`, `DECISIONS.md`, `TODO.md` | Record the reversal. |

Do not create replacement types. Do not add a new Appearance folder.

## Global Constraints

- iOS/iPadOS 18 and macOS 15, Swift 6, system Apple frameworks only.
- The app does not offer an accent picker.
- The app does not compile a custom `AccentColor` (currently the Grape pair).
- The app does not apply a root `.tint(...)`.
- **Mac:** buttons, links, and selected-row chrome follow System Settings → Appearance → Accent color.
- **iPhone / iPad:** the same controls use Apple’s default system blue.
- A leftover `accentKey` value in `UserDefaults` is ignored. Do not migrate or delete it.
- Accessibility identifiers stay (`destination.allItems`, `destination.collections` on the first collection, and so on).
- `List(selection:)` stays so compact iPhone still pushes the detail column.
- The Collections header plus-button and empty-state “Create Collection” button stay as buttons.
- Do not change the app icon.
- Do not add a light/dark appearance override.
- Do not add a new UI test function for the removed settings row. Extend the existing Settings test instead.
- Features is a synchronized Xcode group: deleting Swift files needs no `pbxproj` file-ref edits.
- Delete the `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;` lines. Do not leave the key set to an empty string.
- Work on branch `native-system-accent`. Do not commit to `main`.

---

### Task 1: Point destination queries at any identifier

**Files:**
- Modify: `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift:164-168`

**Interfaces:**
- Consumes: existing `identified(_ identifier: String) -> XCUIElement` at line 160, which is `app.descendants(matching: .any).matching(identifier: identifier).firstMatch`
- Produces: `destinationElement(_ identifier: String) -> XCUIElement` that waits on `identified(identifier)` instead of `app.buttons`

Native sidebar rows after Task 2 are not reliably `XCUIElementTypeButton` on both platforms. The current helper only queries buttons. Change it first so later tasks do not break the suite. Button rows still match `descendants(.any)`, so this task must stay green on current code.

- [ ] **Step 1: Replace `destinationElement`**

In `BookmarkCollectionsUITests.swift`, replace:

```swift
    private func destinationElement(_ identifier: String) -> XCUIElement {
        let button = app.buttons.matching(identifier: identifier).firstMatch
        _ = button.waitForExistence(timeout: 5)
        return button
    }
```

with:

```swift
    private func destinationElement(_ identifier: String) -> XCUIElement {
        let element = identified(identifier)
        _ = element.waitForExistence(timeout: 5)
        return element
    }
```

- [ ] **Step 2: Run the macOS UI suite and confirm it still passes**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsUITests
```

Expected: all UI tests PASS, including `testPrimaryLibraryDestinationsAreReachable`. Current sidebar rows are still buttons, and buttons are descendants.

- [ ] **Step 3: Commit**

```bash
git add BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift
git commit -m "test: query sidebar destinations by identifier, not button type"
```

---

### Task 2: Restore a native tagged sidebar

**Files:**
- Modify: `BookmarkCollections/Features/Collections/CollectionListView.swift` (replace the whole file)

**Interfaces:**
- Consumes: `LibraryDestination` (`Hashable`, `systemImage`, `count(in:)`) and Task 1’s `destinationElement`
- Produces: `CollectionListView` with no `AppAccent` / `@AppStorage` / `SidebarRow`. Rows are `Label` + `.tag(LibraryDestination)` + optional `.badge`. Identifiers unchanged: `destination.allItems`, `destination.images`, `destination.links`, `destination.favorites`, `destination.forgotten`, `destination.recentlyDeleted`, `destination.collections` on the first collection, `destination.collection.<uuid>` on the rest.

- [ ] **Step 1: Replace `CollectionListView.swift` with this file**

```swift
import SwiftData
import SwiftUI

struct CollectionListView: View {
    @Query(sort: [SortDescriptor(\BookmarkCollection.sortPosition), SortDescriptor(\BookmarkCollection.id)])
    private var collections: [BookmarkCollection]
    @Query(sort: [SortDescriptor(\Bookmark.createdAt), SortDescriptor(\Bookmark.id)])
    private var bookmarks: [Bookmark]

    @Binding var selection: LibraryDestination?
    let onCreate: () -> Void
    let onEdit: (BookmarkCollection) -> Void
    let onDelete: (BookmarkCollection) -> Void

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                destinationRow(.allItems, title: "All Items", identifier: "destination.allItems", showsCount: true)
                destinationRow(.images, title: "Images", identifier: "destination.images", showsCount: true)
                destinationRow(.links, title: "Links", identifier: "destination.links", showsCount: true)
                destinationRow(.favorites, title: "Favorites", identifier: "destination.favorites", showsCount: true)
                destinationRow(.forgotten, title: "Forgotten", identifier: "destination.forgotten", showsCount: true)
            }

            Section {
                if collections.isEmpty {
                    Button("Create Collection", systemImage: "folder.badge.plus", action: onCreate)
                } else {
                    ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                        let destination = LibraryDestination.collection(collection.id)
                        destinationRow(
                            destination,
                            title: collection.name,
                            identifier: index == 0
                                ? "destination.collections"
                                : "destination.collection.\(collection.id)",
                            showsCount: true
                        )
                        .contextMenu {
                            Button("Rename") { onEdit(collection) }
                            Button("Delete", role: .destructive) { onDelete(collection) }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Collections")
                    Spacer()
                    Button(action: onCreate) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New Collection")
                }
            }

            Section {
                destinationRow(
                    .recentlyDeleted,
                    title: "Recently Deleted",
                    identifier: "destination.recentlyDeleted",
                    showsCount: false
                )
            }
        }
        .listStyle(.sidebar)
    }

    private func count(for destination: LibraryDestination) -> Int {
        destination.count(in: bookmarks)
    }

    @ViewBuilder
    private func destinationRow(
        _ destination: LibraryDestination,
        title: String,
        identifier: String,
        showsCount: Bool
    ) -> some View {
        if showsCount {
            Label(title, systemImage: destination.systemImage)
                .badge(count(for: destination))
                .tag(destination)
                .accessibilityIdentifier(identifier)
        } else {
            Label(title, systemImage: destination.systemImage)
                .tag(destination)
                .accessibilityIdentifier(identifier)
        }
    }
}
```

Do not keep `SidebarRow`. Do not apply `.listRowBackground`. Do not set `.foregroundStyle` on icons or counts. Do not use `.badge(0)` for Recently Deleted — omit the badge when `showsCount` is false.

- [ ] **Step 2: Build the Mac app**

Run:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED. `AppAccent` still exists and is still used by Settings and the app root; only the sidebar dropped it.

- [ ] **Step 3: Run the macOS UI suite**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsUITests
```

Expected: PASS. `testPrimaryLibraryDestinationsAreReachable` still reaches All Items, Favorites, Forgotten, the first collection (`destination.collections`), and Recently Deleted.

- [ ] **Step 4: Commit**

```bash
git add BookmarkCollections/Features/Collections/CollectionListView.swift
git commit -m "fix: restore native sidebar selection and badges"
```

---

### Task 3: Remove the accent system

**Files:**
- Modify: `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift:114-128`
- Modify: `BookmarkCollections/Features/Settings/SettingsView.swift`
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift:18` and `:34-35`
- Modify: `BookmarkCollections.xcodeproj/project.pbxproj` (two `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` lines)
- Delete: `BookmarkCollections/Features/Appearance/AppAccent.swift`
- Delete: `BookmarkCollections/Features/Appearance/AccentPickerView.swift`
- Delete: `BookmarkCollections/Assets.xcassets/AccentColor.colorset/Contents.json` (and the `AccentColor.colorset` directory)

**Interfaces:**
- Consumes: Task 2’s `CollectionListView`, which no longer references `AppAccent`
- Produces: no `AppAccent` type, no `AccentPickerView`, no Settings Appearance section, no root `.tint`, no compiled `AccentColor`. `SettingsView` Form starts at `Section("Library Data")`.

- [ ] **Step 1: Write the failing assertion on the existing Settings test**

In `testSettingsExposesImportExportAndICloudStatus`, after the four existing `XCTAssertTrue` lines, add:

```swift
        XCTAssertFalse(identified("settings.accentColor").exists)
```

Do not add a new test function.

- [ ] **Step 2: Run only that test and confirm it fails**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsUITests/BookmarkCollectionsUITests/testSettingsExposesImportExportAndICloudStatus
```

Expected: FAIL. `settings.accentColor` still exists on the Appearance row.

- [ ] **Step 3: Strip accent from Settings**

In `SettingsView.swift`, delete these four pieces and nothing else:

1. The property:

```swift
    @AppStorage(AppAccent.storageKey) private var accentKey = AppAccent.defaultAccent.rawValue
```

2. The property:

```swift
    @State private var isPickingAccent = false
```

3. The entire first Form section:

```swift
                Section("Appearance") {
                    Button {
                        isPickingAccent = true
                    } label: {
                        HStack {
                            Label("Accent Color", systemImage: "paintpalette")
                            Spacer()
                            Circle()
                                .fill(selectedAccent.color)
                                .frame(width: 14, height: 14)
                                .accessibilityHidden(true)
                            Text(selectedAccent.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings.accentColor")
                }
```

The Form’s first section after this is `Section("Library Data")`.

4. The sheet:

```swift
        .sheet(isPresented: $isPickingAccent) {
            AccentPickerView()
        }
```

5. The helper:

```swift
    private var selectedAccent: AppAccent {
        AppAccent(storedKey: accentKey)
    }
```

Leave Library Data, iCloud, import/export, and the macOS frame unchanged.

- [ ] **Step 4: Strip accent from the app root**

In `BookmarkCollectionsApp.swift`, delete:

```swift
    @AppStorage(AppAccent.storageKey) private var accentKey = AppAccent.defaultAccent.rawValue
```

Replace:

```swift
            LibraryRootView()
                .tint(AppAccent(storedKey: accentKey).color)
                .task(id: scenePhase) {
```

with:

```swift
            LibraryRootView()
                .task(id: scenePhase) {
```

Do not add `.tint(.accentColor)`. The system default is the point.

- [ ] **Step 5: Delete accent sources and the compiled color**

Delete these paths. Features is synchronized; do not edit file refs in `pbxproj` for the Swift files.

```bash
rm BookmarkCollections/Features/Appearance/AppAccent.swift
rm BookmarkCollections/Features/Appearance/AccentPickerView.swift
rm -rf BookmarkCollections/Assets.xcassets/AccentColor.colorset
```

Leave `AppIcon.appiconset` alone.

- [ ] **Step 6: Remove the global accent build setting**

In `BookmarkCollections.xcodeproj/project.pbxproj`, delete both of these exact lines (app target Release config `9838A13347E11C65B28063CB` and Debug config `E86FF17494F4188F4527F479`):

```
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
```

Do not replace them with an empty-string assignment. Do not touch `ASSETCATALOG_COMPILER_APPICON_NAME`. After the edit, `rg ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME project.pbxproj` must print nothing.

- [ ] **Step 7: Build, then run unit tests and the Settings UI test**

Run:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS'

xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests

xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsUITests/BookmarkCollectionsUITests/testSettingsExposesImportExportAndICloudStatus
```

Expected: BUILD SUCCEEDED, all unit tests PASS, Settings UI test PASS (`settings.accentColor` is gone; import/export/iCloud identifiers remain).

- [ ] **Step 8: Commit**

```bash
git add BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift \
  BookmarkCollections/Features/Settings/SettingsView.swift \
  BookmarkCollections/BookmarkCollectionsApp.swift \
  BookmarkCollections.xcodeproj/project.pbxproj
git add -u BookmarkCollections/Features/Appearance \
  BookmarkCollections/Assets.xcassets/AccentColor.colorset
git commit -m "feat: drop in-app accent picker and compiled Grape tint"
```

---

### Task 4: Docs and full verification

**Files:**
- Modify: `README.md:3` and `:68`
- Modify: `CHANGELOG.md` (insert a dated Changed section)
- Modify: `DECISIONS.md` (append a 2026-08-12 entry after the 2026-07-30 Untuck entry)
- Modify: `TODO.md` (close two backlog items; add one Done item)

**Interfaces:**
- Consumes: the behavior Tasks 2 and 3 shipped
- Produces: tracking docs that match the running app

- [ ] **Step 1: Update README**

In the opening paragraph of `README.md`, delete this sentence and the space before it:

```
 A curated accent palette (Settings → Appearance) tints the app with one of seven colors, each tuned separately for light and dark mode.
```

The Forgotten / Surprise me sentence stays as the last sentence of that paragraph.

In Architecture, replace:

```
- `BookmarkCollections/Features`: adaptive SwiftUI library, editors, Settings, Appearance (accent palette), and Recently Deleted.
```

with:

```
- `BookmarkCollections/Features`: adaptive SwiftUI library, editors, Settings, and Recently Deleted.
```

- [ ] **Step 2: Record the change in CHANGELOG**

Insert this block in `CHANGELOG.md` immediately after the undated `### Added` list (after the `lastOpenedAt` bullet, before `### Fixed — 2026-07-25`):

```markdown
### Changed — 2026-08-12

- Removed the in-app accent picker and custom sidebar pills. Tint and
  sidebar selection now follow the system (macOS system accent; iOS
  default blue).
```

Leave the 2026-07-19 Added bullets in place. They are history.

- [ ] **Step 3: Log the reversal in DECISIONS**

Insert this entry in `DECISIONS.md` after the 2026-07-30 Untuck section and before any later entry (or at the end if Untuck is last):

```markdown
## 2026-08-12 (Native system accent)

- **Decision:** Remove the curated accent palette, Settings → Appearance, and custom sidebar pill selection. Use the platform accent and native `List` selection.
- **Why:** The picker forced custom selection chrome that felt less native than the rest of the app.
- **Alternative considered:** Keep Grape as a compiled `AccentColor` with no picker — rejected; that is still an app-owned color rather than the system accent.
- **Supersedes:** 2026-07-19 Curated accent palette, Grape as default accent, and Sidebar pill selection. Leave those entries in place and treat this one as current.
```

- [ ] **Step 4: Close the sidebar backlog items**

In `TODO.md` Backlog, delete these two bullets:

```
- macOS sidebar keyboard navigation (arrow keys/type-select) lost when sidebar rows became untagged Buttons — restore if it proves annoying.
- Sidebar rows have no pressed/hover affordance with `.plain` button style — consider a hover highlight on macOS.
```

In Done, add:

```
- [x] Restore native sidebar selection (keyboard nav + hover) by dropping custom pills (2026-08-12).
```

Do not delete the older Done items about the accent default or pill styling.

- [ ] **Step 5: Run the full macOS unit and UI suites**

Run:

```bash
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

Expected: both suites PASS. Sidebar destinations still work. Settings has import/export/iCloud and no `settings.accentColor`.

- [ ] **Step 6: Commit**

```bash
git add README.md CHANGELOG.md DECISIONS.md TODO.md
git commit -m "docs: record native system accent reversal"
```

- [ ] **Step 7: Manual checks (human, after the branch is installed)**

Mac: selected sidebar row uses the system accent; changing System Settings → Accent updates Tucked after a relaunch.

iPhone or simulator: Settings has no Appearance section; sidebar uses native selection; tint is system blue.

---

## Self-review

**Spec coverage**

| Spec requirement | Task |
| --- | --- |
| No accent picker | Task 3 |
| No compiled `AccentColor` | Task 3 |
| No root `.tint` | Task 3 |
| Mac follows system accent / iOS default blue | Task 3 (asset + build setting) |
| Ignore leftover `accentKey` | Task 3 (stop reading it; no migration) |
| Native tagged `Label` rows + `.badge` | Task 2 |
| Keep `List(selection:)` | Task 2 |
| Keep create-collection buttons and context menus | Task 2 |
| Keep destination identifiers | Task 2 |
| Settings Appearance gone; Library Data / iCloud stay | Task 3 |
| App icon unchanged | Task 3 (do not touch AppIcon) |
| No appearance override | No task adds one |
| UI helper finds non-button rows | Task 1 |
| No new UI test function | Task 3 extends existing Settings test |
| README / CHANGELOG / DECISIONS / TODO | Task 4 |
| Unit + UI verification | Tasks 1–4 |

**Placeholder scan:** none.

**Type consistency:** `LibraryDestination` tags, `destinationElement` / `identified`, and deleted `AppAccent` / `AccentPickerView` names match across tasks.
