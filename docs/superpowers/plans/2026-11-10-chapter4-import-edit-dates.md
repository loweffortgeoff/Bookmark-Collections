# Chapter 4 Import and Edit Dates Implementation Plan

> Implement inline with the test-first workflow. Do not merge or push.

**Goal:** Preserve non-link items during JSON restore and reserve Date Modified for user edits.
**Architecture:** Keep import mutations in `LibraryImportService`, mirror its kind guard in `JSONImportPreflight`, and report conflicts through the existing import summary. Remove automatic edit-date writes from `BookmarkRepository.markOpened` and `MetadataEnricher`.
**Tech Stack:** Swift 6, SwiftData, XCTest; iOS 18 and macOS 15 minimum.
**Spec:** Approved Chapter 4 F17 and F21 decisions in this session and `DECISIONS.md`.

## Constraints and review focus

- Work on `dev/chapter4-import-edit-dates`; no schema change, merge, or push.
- Preserve images, snippets, dates, organization, and deletion state on a kind conflict, even when the backup is newer.
- Capacity preflight must neither free nor consume a slot for a skipped conflict.
- Opening and metadata fetching must not block a later backup edit through the newer-record safeguard.
- Explicit user edits and collection deletion continue to advance Date Modified.
- F1 remains the accepted interim policy; F15 needs host samples, F24 is conditional, and the other Chapter 4 items remain backlog.

## Task 1: Implement the approved policies

**Files:** `LibraryImportService.swift`, `JSONImportPreflight.swift`, `BookmarkRepository.swift`, `MetadataEnricher.swift` in `BookmarkCollections/Domain/`; focused test files in `BookmarkCollectionsTests/`.
**Interfaces:** Keep `importJSON(_:) throws -> ImportSummary`, `assertCanImport(_:existingBookmarks:) throws`, `markOpened(_:at:) throws`, and metadata entry points unchanged.

- [x] Add regression tests for link collisions with images/snippets, active/deleted state, backup dates, free-limit preflight, and mixed imports.
- [x] Change the existing open-date test and add metadata/restore integration tests. Assert user edits still advance the date.
- [x] Run focused macOS tests. Expected: collision/date regressions fail against the old behavior.
- [x] Add the link-kind guards and remove the two automatic `modifiedAt` assignments.
- [x] Run focused tests. Expected: zero failures.
- [x] Run full Mac and iPhone unit/UI suites separately, and signed iOS plus both simulator scheme builds. Expected: zero failures, documented audit skips only.
- [ ] Review the whole diff, update the project records, and commit the completed changes locally.

**Focused command:** `xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/JSONImportKindCollisionTests -only-testing:BookmarkCollectionsTests/BookmarkEditDateTests -only-testing:BookmarkCollectionsTests/BookmarkRepositoryTests -only-testing:BookmarkCollectionsTests/JSONImportNewerRecordTests -only-testing:BookmarkCollectionsTests/MetadataEnricherTests`
