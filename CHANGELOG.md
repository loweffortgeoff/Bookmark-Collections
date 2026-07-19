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
- New Tucked app icon: a curious star peeking from a pocket in the Dusk Candy palette.
- Get Info panel on the bookmark context menu (URL, title, collection, favorite, added/modified dates).
- Save images and screenshots via the Share Sheet; new Images and Links sidebar filters; full-screen image viewer.
- Sidebar shows item counts for All Items, Images, Links, Favorites, and each collection.

### Fixed — 2026-07-19

- Unified the library grid's adaptive column band across platforms. Mac and iOS/iPad previously used divergent ranges (Mac 220–320, iOS/iPad 160–260), producing a ~100pt "sawtooth" in card size as the window resized and making Mac/iPad density feel inconsistent. Both platforms now share `.adaptive(minimum: 160, maximum: 210)`; spacing stays platform-specific (14 iOS / 18 Mac). The minimum floor is held at 160 to preserve 2-column layout on iPhone SE (375pt width), so the band was narrowed by lowering the max rather than raising the min.
- Fixed a torn/cropped "window shade" artifact in the library grid during live iPadOS window resizing. `LazyVGrid` cells were retaining stale geometry mid-drag, which `BookmarkCard`'s clipped preview area then rendered against new cell bounds. The grid's `ScrollView` is now wrapped in a `GeometryReader` with a width-bucketed `.id()` that forces `LazyVGrid` to fully rebuild cells when available width crosses a ~20pt threshold, rather than relying on in-place relayout.
- Image viewer title is now inline; image cards show their added date instead of an empty domain line.
- Viewer and Get Info sheet minimum-size frames are macOS-only; they previously forced content wider than iPhone screens, clipping toolbars. Convention going forward: min-size frames on sheets belong in `#if os(macOS)`.

### Verification

- 47 unit tests pass on native macOS and iPhone simulator.
- 10 UI tests pass on native macOS and iPhone simulator.
- Signed iOS app and Share Extension build and validate with matching App Group and CloudKit entitlements.
- Real-device CloudKit, Production schema, and TestFlight checks remain release gates; see `docs/verification/cloudkit-device-matrix.md`.
