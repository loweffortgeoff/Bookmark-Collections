# Changelog

All notable project changes are recorded here.

## 1.0.0 — Unreleased

### Added

- Universal SwiftUI bookmark library for iPhone, iPad, and Mac.
- Local-first SwiftData storage with private CloudKit mirroring.
- Share Extension with immediate validated URL saving through the shared App Group.
- Visual preview cards, Favorites, single-membership Collections, search, sorting, drag-and-drop, context menus, and bulk actions.
- Recently Deleted with restore, confirmed permanent deletion, and 30-day purge behavior.
- Link metadata enrichment with durable URL fallback when metadata fails.
- UTF-8 text import, portable HTML export, and versioned JSON backup/restore.
- Settings with honest iCloud account availability and import/export summaries.
- Native macOS commands, keyboard focus behavior, semantic accessibility labels, and adaptive light/dark Dynamic Type layouts.
- Duplicate reconciliation for independently saved normalized URLs after CloudKit merges.

### Verification

- 37 unit tests pass on native macOS and iPhone simulator.
- 8 UI tests pass on native macOS and iPhone simulator.
- Signed iOS app and Share Extension build and validate with matching App Group and CloudKit entitlements.
- Real-device CloudKit, Production schema, and TestFlight checks remain release gates; see `docs/verification/cloudkit-device-matrix.md`.
