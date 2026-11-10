# Adversarial Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the data-loss, crash, and dead-end bugs found in the 2026-11-09 adversarial review of Tucked 1.1.0 (`main` at `9b39d7d`).

**Architecture:** Three chapters, one branch each, in severity order. Each chapter is merge-ready alone. No schema change, no new dependency. Chapter 4 holds decisions for Geoff and has no code.

**Tech Stack:** Swift 6, SwiftUI, SwiftData + CloudKit, StoreKit 2, XCTest.

**Spec:** The Findings section of this file. Evidence is code reading at `9b39d7d` unless a row says "run".

## Resume here (updated 2026-11-10, Chapter 3)

1. Chapters 1 and 2 are merged locally to `main` at `bffbf0b` (fast-forward, 2026-11-10, with Geoff’s authorization). No push performed.
2. Chapter 2 merge gate at `bffbf0b`, Mac mini, macOS 27.2, Xcode 27.2, scheme `BookmarkCollections`: Mac unit 254 cases (15 skipped), Mac UI 17 (1 skipped), iPhone 18 Pro iOS 27.0 unit 250 (15 skipped), UI 18 (1 skipped). Zero failures. The Mac UI suite ran after Geoff authorized Automation Mode.
3. Chapter 3 is built on `fix/review-ui-traps`, `456b450`..`db57eeb`. All six tasks are done. Code review found three Important items; `db57eeb` fixes them.
4. Chapter 3 exit suites at `db57eeb`, same machine: Mac unit 261 (15 skipped), Mac UI 19 (1 skipped), iPhone unit 257 (15 skipped), iPhone UI 19 (1 skipped). Zero failures. Both simulator schemes build.
5. Chapter 3 is merged locally to `main` at `bf083a4` (fast-forward, 2026-11-10, with Geoff’s authorization). Not pushed; Geoff pushes `main`. The merged branches `fix/review-data-loss` and `fix/review-enrichment-purchase` are deleted, local and on `origin`. No visual check of the import-summary Unlock row or the image viewer was done; tests and builds only.
6. Chapter 4 is decisions only. No code until Geoff chooses.

## Global Constraints

- iOS 18.0 and macOS 15.0 deployment targets. No third-party dependencies.
- No SwiftData schema change in this plan (a schema change needs a Production CloudKit deploy).
- Both schemes must build after every task: `BookmarkCollections` and `BookmarkShareExtension`, `-destination 'generic/platform=iOS Simulator'`, no `-quiet`.
- Tests: `-only-testing:BookmarkCollectionsTests/<Class>`, `-parallel-testing-enabled NO`, `-collect-test-diagnostics never`, iPhone 18 Pro `204520A6-E5B5-447D-8A6B-028317014DD8` (iOS 27.0). Full suite only before each merge to `main`.
- One branch per chapter. Claude commits; Geoff pushes.
- Existing free-limit behaviour must not change (`BookmarkLimitTests`, `PaywallGateAuditTests`, `PaywallImportAuditTests` stay green).

## Findings

| # | Sev | Finding | Location |
|---|-----|---------|----------|
| F1 | Critical | Same JSON backup imported on two devices before sync: each record exists twice with equal `id` and `createdAt`. The reconcile tie-break is then decided by local fetch order, so each device hard-deletes the other device's copy. After sync, the link is gone on both. | `BookmarkRepository.swift:259-281` |
| F2 | Critical | Same scenario leaves snippets and collections duplicated with equal `id` forever (reconcile handles links only). The next JSON import traps in `Dictionary(uniqueKeysWithValues:)`. Duplicate `id`s also feed `ForEach`. | `LibraryImportService.swift:74,97`, `JSONImportPreflight.swift:16`, `LibraryGridView.swift:46` |
| F3 | High | Metadata enrichment always overwrites the title. JSON import sets every link to `.pending`, so restored custom titles are replaced by page titles. An edited title on a pending or failed link is also replaced. Refresh Preview renames too. | `MetadataEnricher.swift:73-75`, `LibraryImportService.swift:150` |
| F4 | High | A repeat save resets collection and Favorite. Text import and URL drop pass the defaults (no collection, not favorite), so every already-saved link in the file is unfiled and unfavorited. | `BookmarkRepository.swift:111-117`, `LibraryImportService.swift:34`, `LibraryGridView.swift:80` |
| F5 | High | Reconcile keeps the earliest record even when it is soft-deleted, and hard-deletes the active copy. A saved or imported link lands in Recently Deleted. | `BookmarkRepository.swift:265,279-281` |
| F6 | High | Enrichment runs only when `scenePhase` changes to active, 20 links per run. A link added in the app has no title or preview until the app is backgrounded and reopened. A 200-link import needs 10 activations. A failure (for example offline) waits 1 hour and another activation. | `BookmarkCollectionsApp.swift:59-67`, `MetadataEnricher.swift:8,37` |
| F7 | High | `Storefront.load()` runs once, at init. If the product did not load (offline launch), the paywall shows a disabled Unlock button and a hard-coded "$4.99" until relaunch. | `Storefront.swift:28-30`, `PaywallView.swift:118,145` |
| F8 | High | `try!` on `ModelContainer` creation. Any store-open failure is a crash on every launch, with no message. | `BookmarkCollectionsApp.swift:25` |
| F9 | Medium | `purgeExpiredDeleted` has no caller. The UI promises 30 days; deleted items stay and sync forever. | `BookmarkRepository.swift:327`, `LibraryGridView.swift:202` |
| F10 | Medium | Enrichment writes to bookmarks after an `await` with no liveness check, and its batch includes soft-deleted links. Empty Recently Deleted, or a remote delete, during a batch can write to a destroyed model (SwiftData fatal error). | `MetadataEnricher.swift:18-45,64-94`, `LibraryRootView.swift:45-48` |
| F11 | Medium | `URL(string: bookmark.urlString)!` in the context menu. Any link-kind record with an empty or unparseable URL crashes on long-press. An unknown future kind maps to `.link` with an empty URL. | `BookmarkActions.swift:43`, `Bookmark.swift:43` |
| F12 | Medium | Selection mode survives a destination change. In Recently Deleted or an empty view the Done button is hidden while the action bar stays; bulk Delete there re-stamps `deletedAt`. | `LibraryGridView.swift:23-24,96-110` |
| F13 | Medium | Add Link rejects `example.com` and `www.example.com/page` with "Enter a valid web address." (run: `NormalizedURL` on Mac mini, macOS 27). Text import fails the same lines. | `NormalizedURL.swift:28-30`, `AddBookmarkView.swift:58` |
| F14 | Medium | At the free limit, Save in the snippet editor replaces the editor sheet with the paywall. The typed text is lost. The menu bar and Cmd+N do the same to any open editor. | `LibraryRootView.swift:102,206`, `SnippetEditorView.swift:124` |
| F15 | Medium | Share from apps that send a title string plus a URL (the common `[String, URL]` pattern) is saved as a text snippet, not a link. On Mac this is silent. | `ShareCaptureModel.swift:292-303` |
| F16 | Medium | Suspected, not verified: with a sheet open on Mac, Cmd+Delete in a text field triggers "Move to Recently Deleted" on the edited bookmark. | `BookmarkCommands.swift:69-71`, `LibraryRootView.swift:325-332` |
| F17 | Medium | JSON import overwrites an existing record with the backup's values, with no `modifiedAt` comparison, and clears its preview. A link record whose `id` matches an image bookmark erases the image. | `LibraryImportService.swift:113-151` |
| F18 | Medium | Text import and image import throw at the free limit mid-loop. Earlier lines are already saved, and no summary is shown. | `LibraryImportService.swift:42-43`, `ImageImportService.swift:31-32` |
| F19 | Medium | Bulk Share sends link URLs only. Images and snippets in the selection are dropped; an image-only selection shares nothing. | `LibraryGridView.swift:140` |
| F20 | Low | Image viewer decodes the full image on every body pass (twice), including each pinch frame. A zoomed image cannot be panned. | `ImageViewerView.swift:19,53,68-77` |
| F21 | Low | Opening an item bumps `modifiedAt`: Date Modified sort and Get Info change, and each open is a sync write. A test asserts this, so it is a decision. | `BookmarkRepository.swift:290-294` |
| F22 | Low | URL drop works only on a non-empty grid, ignores the current collection, and stops at the first bad URL. | `LibraryGridView.swift:76-91` |
| F23 | Low | Export file names and the HTML title still say "Bookmark Collections". JSON "backup" omits images with no warning (Backlog). No HTML import. | `SettingsView.swift:140,146`, `LibraryExportService.swift:21,88` |
| F24 | Risk | The Share extension opens its own CloudKit-mirrored container on the same store as the app. Two mirroring processes on one store is outside what Apple documents as supported. Not verified here. | `ShareViewController.swift:31,138` |

## Review Focus

- Two devices, same backup, both online at once: no record may be hard-deleted unless both devices pick the same survivor (Task 1.1 test).
- A library that already holds equal-`id` duplicates from 1.1.0: import must not trap (Task 1.2 test).
- A restored backup with custom titles, then enrichment: titles stay (Task 1.3 test).
- A user who deletes a link, then imports or re-saves it on another device: the link is active afterwards (Task 1.1 test).
- A free user at 10 items: none of these changes may let an 11th active item in, or block an edit (existing audit suites).

---

## Chapter 1 — Data loss (branch `fix/review-data-loss`)

> **Chapter 1 status (2026-11-09):** built on `fix/review-data-loss`, commits `7f3e610`..`7770209`. Merged locally to `main` at `411b8e8` with Geoff’s authorization. Review changed two rules in Task 1.1; the text below is the original and the rule as built is here:
>
> - **Canonical** is always the earliest record by `createdAt`, then `id`. It is never chosen by `deletedAt`: that field changes and syncs late, so two devices could pick different survivors.
> - **Survivors** are the canonical and its clones (same `id` and `createdAt`). Every other record in the group is hard-deleted, and the merged values go to every survivor.
> - **A group of clones only is left alone.** No merge, no revive, no save. A copy the user deletes stays deleted.
> - **Revive:** `deletedAt` is cleared on the survivors only when none of them is active and a record removed from the group was active.
> - **Preflight** counts a link group as 1 when any member is active. At 10 active, a JSON import of an active copy of a deleted link now stops at the free limit; in 1.1.0 it reported success and left the link deleted.
> - **Known limits, accepted:** an import updates one copy of a snippet clone pair; the preflight counts an equal-id pair once, so a free user who holds clone pairs can pass the cap by that number.

### Task 1.1: Reconcile never guesses and never keeps a deleted canonical

**Files:**
- Modify: `BookmarkCollections/Domain/BookmarkRepository.swift:246-288`
- Modify: `BookmarkCollections/Domain/JSONImportPreflight.swift:48-68`
- Test: `BookmarkCollectionsTests/BookmarkRepositoryTests.swift`, `BookmarkCollectionsTests/PaywallImportAuditTests.swift`

**Interfaces:**
- Produces: `reconcileDuplicates()` unchanged signature. New rules: (a) canonical is the earliest-created **active** record when the group has one, else the earliest; (b) a duplicate whose `id` **and** `createdAt` equal the canonical's is left in place, not deleted.

- [ ] **Step 1: Write failing tests**

```swift
func testReconcileKeepsActiveCopyWhenEarliestIsDeleted() throws
// earliest (createdAt 100) has deletedAt set; later (createdAt 200) is active.
// After reconcile: exactly 1 record, deletedAt == nil, id == later.id.

func testReconcileLeavesExactClonesUntouched() throws
// Two links, same id, same createdAt, same normalizedURLString.
// After reconcile: count == 2.

func testReconcileStillMergesClonesWithADistinctThirdRecord() throws
// Clones A, A' (same id/createdAt 100) plus B (createdAt 200, favorite).
// After reconcile: B is gone, count == 2, both survivors isFavorite.
```

- [ ] **Step 2: Run** `-only-testing:BookmarkCollectionsTests/BookmarkRepositoryTests`. Expected: the three new tests fail.
- [ ] **Step 3: Implement the two rules in `reconcileDuplicates()`.** Merged fields (favorite, title, collection, `modifiedAt`, `lastOpenedAt`) are written to the canonical and to every surviving clone.
- [ ] **Step 4: Mirror rule (a) and (b) in `JSONImportPreflight.reconciledActiveCount`.** A group with any active item counts 1 plus the number of surviving active clones. Add `testPreflightCountsActiveCopyWhenEarliestIsDeleted` to `PaywallImportAuditTests`: 9 active + 1 deleted existing; import the deleted URL as active with a new id; expect no throw and 10 active after import.
- [ ] **Step 5: Run** `BookmarkRepositoryTests`, `PaywallImportAuditTests`, `ImportExportTests`. Expected: pass. Build both schemes.
- [ ] **Step 6: Commit** `Stop reconcile from deleting clones or keeping a deleted canonical`.

### Task 1.2: Tolerate equal-id records

**Files:**
- Modify: `BookmarkCollections/Domain/LibraryImportService.swift:74,97`
- Modify: `BookmarkCollections/Domain/JSONImportPreflight.swift:16`
- Modify: `BookmarkCollections/Features/Library/LibraryGridView.swift:46`, `BookmarkCollections/Features/Collections/CollectionListView.swift:35`
- Test: `BookmarkCollectionsTests/ImportExportTests.swift`

- [ ] **Step 1: Write failing test** `testImportDoesNotTrapWhenLibraryHoldsEqualIDRecords`: insert two snippets with one `id` and two collections with one `id`, run `importJSON` on a document that names both ids, assert it returns and `summary.duplicateCount == 1`.
- [ ] **Step 2: Run** `ImportExportTests`. Expected: the process crashes on the new test.
- [ ] **Step 3: Replace the three `Dictionary(uniqueKeysWithValues:)` calls** with `Dictionary(_:uniquingKeysWith: { first, _ in first })`.
- [ ] **Step 4: Key the grid and sidebar `ForEach` by `\.persistentModelID`.** Selection stays `Set<UUID>`.
- [ ] **Step 5: Run** `ImportExportTests`, `PaywallImportAuditTests`. Build both schemes.
- [ ] **Step 6: Commit** `Tolerate equal-id records in import and lists`.

### Task 1.3: Enrichment keeps an existing title

**Files:**
- Modify: `BookmarkCollections/Domain/MetadataEnricher.swift:73-75`
- Test: `BookmarkCollectionsTests/MetadataEnricherTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testEnrichmentKeepsAnExistingTitle() async throws
// bookmark.title = "My Title", state .pending; provider returns title "Page Title".
// After enrichPending(limit: 1): title == "My Title", metadataState == .ready.

func testRefreshKeepsAnExistingTitle() async throws
// Same through refresh(_:).
```

- [ ] **Step 2: Run** `MetadataEnricherTests`. Expected: both fail with "Page Title".
- [ ] **Step 3: Set the title only when `bookmark.title.isEmpty`.**
- [ ] **Step 4: Run** `MetadataEnricherTests`, `ImportExportTests`. Build both schemes.
- [ ] **Step 5: Commit** `Keep user and restored titles during metadata enrichment`.

### Task 1.4: Import and drop keep organization on repeat saves

**Files:**
- Modify: `BookmarkCollections/Domain/BookmarkRepository.swift:48-54`
- Modify: `BookmarkCollections/Domain/LibraryImportService.swift:34`, `BookmarkCollections/Features/Library/LibraryGridView.swift:80`
- Test: `BookmarkCollectionsTests/ImportExportTests.swift`

**Interfaces:**
- Produces: `func save(url: String, collection: BookmarkCollection? = nil, favorite: Bool = false, preserveOrganization: Bool = false) throws -> SaveResult`. Add Link keeps the default `false` (the form is explicit).

- [ ] **Step 1: Write failing test** `testTextImportKeepsCollectionAndFavoriteOfExistingLink`: save a link in collection "Reading" with favorite on, `importText` the same URL, assert collection id unchanged, `isFavorite == true`, `summary.duplicateCount == 1`.
- [ ] **Step 2: Run** `ImportExportTests`. Expected: fail.
- [ ] **Step 3: Add the parameter; pass `true` from `importText` and the drop handler.**
- [ ] **Step 4: Run** `ImportExportTests`, `BookmarkRepositoryTests`. Build both schemes.
- [ ] **Step 5: Commit** `Keep collection and Favorite when import or drop repeats a link`.

**Chapter 1 exit:** full suite on both platforms, then merge. Add a CHANGELOG entry and check off TODO.

---

## Chapter 2 — Previews, purge, purchase (branch `fix/review-enrichment-purchase`)

### Task 2.1: Safe, prompt enrichment

Review correction (Session 2, after `a6151f9`): the original count-keyed batch restarted mid-fetch and could miss same-count replacements. The interfaces below replace that scheduling rule; the original implementation report and review remain in `.superpowers/sdd/2026-11-09-adversarial-review-fixes/`.

**Files:**
- Modify: `BookmarkCollections/Domain/MetadataEnricher.swift:13-46,64-94`
- Modify: `BookmarkCollections/Features/Library/LibraryRootView.swift` (add one `.task(id:)`)
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift` (activation retries only)
- Test: `BookmarkCollectionsTests/MetadataEnricherTests.swift`
- Test: `BookmarkCollectionsTests/MetadataEnricherSchedulingTests.swift`

**Interfaces:**
- Produces: `enrichPending(limit:includePending:)`, with `includePending` defaulting to `true`, preserves existing pending-first batch semantics and per-result saves. Activation calls it with `limit: 20, includePending: false` to retry only active failed links whose hourly delay has elapsed.
- Produces: in `LibraryRootView`, `oldestPendingRequest: PendingMetadataRequest?` selects the first active pending link in `createdAt`, then `id` order. Key `.task(id:)` by the captured persistent ID and URL; call `enrichPendingBookmark(id:)` for only that record. Skip `-ui-testing`. Finishing or deleting the record changes the key even for clone UUIDs and same-count replacements; a missing or ineligible keyed record is skipped without selecting a replacement.
- Preserves cancellation and model-liveness checks before reads and after awaits. Discard both success and failure if `lastMetadataRefreshAt` changed during the request or the stored row no longer exists; discarded results do not save. Cover two-enricher completion order and second-context deletion with focused tests.

- [x] **Step 1: Write failing tests**

```swift
func testPendingEnrichmentSkipsSoftDeletedLinks() async throws
// One pending link with deletedAt set. Provider call count == 0 after enrichPending.

func testEnrichmentSurvivesDeletionDuringFetch() async throws
// Provider's metadata(for:) deletes the bookmark from the context and saves, then returns.
// enrichPending returns without a crash; fetch count == 0.
```

- [x] **Step 2: Run** `MetadataEnricherTests`. Before implementation, both failed; deletion caused an extra provider call rather than a crash on this runtime.
- [x] **Step 3: Implement the three rules in `MetadataEnricher`.**
- [x] **Step 4: Capture `oldestPendingRequest` as `pendingRequest` and add `.task(id: pendingRequest)` to `LibraryRootView`, with one-record enrichment.** Skip `-ui-testing`; restrict activation to due failed links only.
- [x] **Step 5: Run** `MetadataEnricherTests`. Build both schemes.
- [x] **Step 6: Visually confirm** on iPhone 18 Pro: Add Link `https://www.apple.com`; the title and preview appear with no backgrounding.
- [x] **Step 7: Commit** `Enrich new links at once and guard against deleted records`.

### Task 2.2: Purge expired deletions

**Files:**
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift:59-67`
- Test: `BookmarkCollectionsTests/RecentlyDeletedTests.swift` (the repository method is already covered; no new test)

- [x] **Step 1: Call `try? repository.purgeExpiredDeleted()` in the activation task, after `reconcileDuplicates()`, and make the purge skip any link whose normalized URL also has an active record.** Chapter 1 review found a race otherwise: one device purges a just-expired deleted copy while another revives it and deletes the active copy, and both are gone after sync. Add `testPurgeSkipsDeletedLinkWithAnActiveCopy` to `RecentlyDeletedTests`.
- [x] **Step 2: Run** `RecentlyDeletedTests`. Build both schemes.
- [x] **Step 3: Commit** `Purge Recently Deleted items after 30 days`.

Geoff: this is the first build that hard-deletes on a timer. Items deleted more than 30 days ago go on first launch, on every device. **Accepted by Geoff 2026-11-09.**

**Approved F17 follow-up, brought forward from Chapter 4 (2026-11-09):**

- [x] Preserve newer same-ID links, snippets, and collections during JSON import; equal/newer backups still apply. Mirror dates in capacity preflight, including records already processed from the same file; preserve clone selection and kind-collision policy.
- [x] Add focused regressions for stale tombstones after restore/purge, newer deletions and edits, equal/newer backups, and free-cap rejection without mutations. All 58 tests in `JSONImportNewerRecordTests`, `ImportExportTests`, `PaywallImportAuditTests`, and `RecentlyDeletedTests` pass on iPhone 18 Pro, iOS 27.0.
- [x] Complete the [two-device purge/restore check](../../verification/cloudkit-device-matrix.md#chapter-2-purgerestore--2026-11-09). Geoff reported pass on 2026-11-10 (both physical iPhones at `126b913`). The local guard narrows the race but cannot protect an unseen remote restore; Geoff accepted this limit. Reconciliation can keep an older deletion date when both independent duplicates are deleted; leave that behavior unchanged.

**Execution method (Geoff, 2026-11-09):** subagent-driven, one chapter per session.

### Task 2.3: Paywall retries the product and shows no invented price

**Files:**
- Modify: `BookmarkCollections/Features/Paywall/PaywallView.swift:59,118`
- Modify: `BookmarkCollections/Domain/Storefront.swift:37-57`
- Test: `BookmarkCollectionsTests/StorefrontAuditTests.swift`

- [x] **Step 1: In `PaywallView`, add `.task { if storefront.product == nil { await storefront.load() } }`.**
- [x] **Step 2: Make `load()` return early when `isLoading` is already true.**
- [x] **Step 3: Replace the `"$4.99"` fallback** with a `ProgressView` while `isLoading`, and no price row otherwise.
- [x] **Step 4: Run** `StorefrontAuditTests`, `PaywallGateAuditTests`. Build both schemes.
- [x] **Step 5: Commit** `Retry the product load when the paywall opens`.

### Task 2.4: Store-open failure shows a screen, not a crash

**Files:**
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift:20-32,55-68`

- [x] **Step 1: Make `container` optional; catch the error and log it with `ShareStorageDiagnostics.logSummary`.**
- [x] **Step 2: When it is nil, show `ContentUnavailableView("Tucked Couldn’t Open Your Library", systemImage: "externaldrive.badge.exclamationmark", description: Text("Restart your device. If this continues, contact support."))` with the Support link from `AboutLink.support`.** No in-memory fallback: silent saves to a throwaway store are worse than a message.
- [x] **Step 3: Build both schemes. Run** `ModelContainerTests`.
- [x] **Step 4: Commit** `Show a failure screen when the library cannot open`.

**Chapter 2 exit:** full suite on both platforms, then merge.

---

## Chapter 3 — UI traps (branch `fix/review-ui-traps`)

> **Chapter 3 status (2026-11-10):** built on `fix/review-ui-traps`, commits `456b450`..`db57eeb`. Merged locally to `main` at `bf083a4` with Geoff’s authorization. The text below is the original; these rules changed as built:
>
> - **Task 3.3:** text with a real scheme (`mailto:`) stays as typed and gets the unsupported-scheme message. The planned `https://mailto:a@b.com` parses as a valid address. `https://` is added only when the host ends in a letters-only label of two or more letters and the text has no `@`, so `v1.2`, `3.14` and `user@example.com` stay invalid lines in a text import.
> - **Task 3.4:** the editors no longer take `onPaywall`; `SettingsView` keeps it. A menu bar request that arrives while an editor is open is taken and dropped, not kept: a kept request fired on the next window appearance. Surprise Me and Add Images are also inert while a sheet is open. The collection editors count as editors with a draft.
> - **Task 3.4, F16:** confirmed real on `bffbf0b` and closed. `testCommandDeleteInSnippetEditorDoesNotDeleteTheSnippet` is the regression test.
> - **Task 3.5:** the Mac Add Images command opens the paywall when its batch stops at the limit.
> - **Task 3.6:** the decode is keyed by image data size, so data that syncs in later is decoded.

### Task 3.1: Remove the force unwrap

**Files:** Modify `BookmarkCollections/Features/Bookmark/BookmarkActions.swift:42-46`

- [x] **Step 1: Show the link `ShareLink` only when `BookmarkSharePayload(bookmark:)` is `.link(url)`.**
- [x] **Step 2: Build both schemes. Commit** `Remove the force-unwrapped share URL`.

### Task 3.2: Selection mode ends with its view

**Files:** Modify `BookmarkCollections/Features/Library/LibraryGridView.swift:96-111`; Test `BookmarkCollectionsUITests/BookmarkCollectionsUITests.swift`

- [x] **Step 1: Write failing UI test** `testSelectionModeEndsWhenDestinationChanges`: tap `selection.toggle`, select "Seeded Active", tap `destination.recentlyDeleted`, assert `selection.delete` does not exist.
- [x] **Step 2: Add `.onChange(of: destination) { isSelecting = false; selection.removeAll() }`.** Show the Done button whenever `isSelecting` is true.
- [x] **Step 3: Bulk Share (F19):** disable the Share control when the selection has no link.
- [x] **Step 4: Run** `-only-testing:BookmarkCollectionsUITests/BookmarkCollectionsUITests/testSelectionModeEndsWhenDestinationChanges`. Commit `End selection mode when the destination changes`.

### Task 3.3: Accept addresses with no scheme

**Files:** Modify `BookmarkCollections/Domain/NormalizedURL.swift`, `Features/Bookmark/AddBookmarkView.swift:58`, `Domain/LibraryImportService.swift:34`; Test `BookmarkCollectionsTests/NormalizedURLTests.swift`

**Interfaces:**
- Produces: `static func userEntered(_ value: String) -> String` on `NormalizedURL`. Trims whitespace. If the value has no `://` and contains a `.` and no whitespace, it returns `"https://" + value`; otherwise the trimmed value. Share capture does not use it.

- [x] **Step 1: Write failing tests**

```swift
func testUserEnteredAddsHTTPS() {
    XCTAssertEqual(NormalizedURL.userEntered("example.com"), "https://example.com")
    XCTAssertEqual(NormalizedURL.userEntered(" www.example.com/page "), "https://www.example.com/page")
    XCTAssertEqual(NormalizedURL.userEntered("http://example.com"), "http://example.com")
    XCTAssertEqual(NormalizedURL.userEntered("mailto:a@b.com"), "https://mailto:a@b.com") // then fails validation
    XCTAssertEqual(NormalizedURL.userEntered("not a url"), "not a url")
}
```

- [x] **Step 2: Implement; call it from Add Link and `importText`.**
- [x] **Step 3: Run** `NormalizedURLTests`, `ImportExportTests`. Build both schemes. Commit `Accept web addresses typed without a scheme`.

### Task 3.4: The paywall does not discard a draft

**Files:** Modify `Features/Bookmark/SnippetEditorView.swift:122-128`, `Features/Bookmark/AddBookmarkView.swift:64-69`, `Features/Library/LibraryRootView.swift:100-113,300-336`

- [x] **Step 1: In both editors, present `PaywallView()` from a local `@State private var showsPaywall` `.sheet`** in place of `onPaywall()`. The editor stays under it with its text. Keep the `onPaywall` parameter for Settings.
- [x] **Step 2: In `commandActions`, when `sheet != nil` pass `selectedBookmark: nil`, `canDeleteSelected: false`, and make `addLink`, `newSnippet`, `newCollection` no-ops.** This also closes F16. In `visibleCommandBookmark`, match by `persistentModelID`, not `id`, so a command on one clone cannot act on the other.
- [x] **Step 3: `consumeMenuBarRequest`: return without `take()` while `sheet` is `.snippetEditor`, `.editBookmark`, or `.addBookmark`.** The window still comes forward.
- [x] **Step 4: Check F16 on the Mac mini before and after:** open a snippet, press Cmd+Delete in the text, close, look in Recently Deleted. Record the result in the commit body.
- [x] **Step 5: Run** `BookmarkCollectionsUITests/PaywallFlowAuditTests` and `MacCommandSharingUITests`. Commit `Keep editor drafts when the paywall or a menu command appears`.

### Task 3.5: Import reports partial results

**Files:** Modify `Domain/BackupDocument.swift:75-80`, `Domain/LibraryImportService.swift:42-43`, `Domain/ImageImportService.swift:31-32`, `Features/Settings/ImportSummaryView.swift`, `Features/Settings/SettingsView.swift:130-136`; Test `BookmarkCollectionsTests/PaywallImportAuditTests.swift`

**Interfaces:**
- Produces: `var stoppedAtLimit = false` on `ImportSummary`. `importText` and `importImages` set it and `break` in place of the rethrow. `ImportSummaryView` shows a row "Stopped at the free limit" with an Unlock button when it is true.

- [x] **Step 1: Write failing test** `testTextImportAtLimitReturnsSummary`: free, enforced, 8 existing; import 5 new URLs; expect `newCount == 2`, `stoppedAtLimit == true`, no throw. Update the existing audit test that expects a throw.
- [x] **Step 2: Implement. Run** `PaywallImportAuditTests`, `ImageImportTests`, `ImportExportTests`. Build both schemes. Commit `Report partial imports that stop at the free limit`.

### Task 3.6: Image viewer decodes once

**Files:** Modify `Features/Bookmark/ImageViewerView.swift`

- [x] **Step 1: Decode into `@State private var image: Image?` in `.task`;** body and toolbar read the state.
- [x] **Step 2: Build both schemes. Commit** `Decode the viewer image once`. Pan-while-zoomed stays out (Chapter 4).

**Chapter 3 exit:** full suite on both platforms, then merge.

---

## Chapter 4 — Decisions for Geoff (no code until chosen)

1. **F1 full fix.** Chapter 1 stops the loss but leaves clone pairs visible; the user deletes one by hand. A clean merge needs a synced per-record token (schema change plus Production CloudKit deploy). Recommendation: ship Chapter 1, add the token only if clones are seen in the field. **Decided 2026-11-09 (Geoff): ship Chapter 1 as written. Condition: if no permanent fix follows, that must be stated in writing (DECISIONS.md and the release notes), not left silent. Tracked on the TODO Watch List.**
2. **F15 share heuristic.** Option: when an item has both a URL and text, save a link and use the text as the title unless the host is Safari-style selection (text longer than about 200 characters or multi-line). Needs device captures from 3 or 4 real apps first.
3. **F17 import policy, remaining decision.** The newer-`modifiedAt` safeguard was approved and brought forward into Chapter 2 on 2026-11-09. Still pending: decide whether to reject a link record for a non-link `id`; no kind-collision policy changed in Chapter 2.
4. **F21 `modifiedAt` semantics.** Decide which writes count as edits: opens, metadata fetches, and collection deletion currently advance the date and can make later-imported backup edits look older under the approved F17 safeguard. Recommendation: stop the bump on open; assess metadata separately. No code change chosen here.
5. **F24 extension CloudKit.** Try `cloudKit: false` in the extension on a device pair; the app exports the record on next launch. Only if Share storage errors return.
6. **F22, F23, F20 pan.** Backlog.
