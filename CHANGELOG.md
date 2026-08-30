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
- Forgotten library destination: never-opened items older than 30 days.
- Surprise me toolbar action: opens a random item from the current visible set.
- Track `lastOpenedAt` when opening links or the image viewer; include it in JSON backups.
- Text snippets: a third bookmark kind holding a piece of text with an optional source link, its own Snippets sidebar destination, a text-excerpt card, and Copy Text. Search matches snippet bodies.
- JSON backup carries snippets under a top-level `snippets` key. A backup written before this change still restores.
- `File ▸ Add Images…` on macOS adds images from a file picker rather than only through the Share menu.

### Changed — 2026-08-12

- Removed the in-app accent picker and custom sidebar pills. Tint and
  sidebar selection now follow the system (macOS system accent; iOS
  default blue).

### Fixed — 2026-08-29

- Share-extension storage failures now show a clear recovery step and log the
  underlying local error instead of showing an unexplained Retry action.
- Fixed the macOS application menu name. It used `CFBundleName`, which still
  expanded to the internal `BookmarkCollections` target name despite the
  display name already being Tucked.
- Fixed the multi-select bottom bar's action labels wrapping into a
  letter-stack ("Fa/vo/rit/e") under space pressure — switched to icon-only
  buttons, spread full-width with `Spacer()`s, with the surrounding
  background removed (see DECISIONS.md, 2026-08-29).

### Fixed — 2026-07-25

- Fixed the Mac never actually installing. `scripts/install-all-devices.sh`
  built the Mac app and launched it in place out of `build/DerivedData`, so the
  only copy lived in a build directory that the next rebuild, macOS UI test run,
  or `scripts/reset-ui-tests.sh` deleted — the app stopped running with nothing
  left to relaunch, and Spotlight had no installed app to find. The Mac now
  installs to `/Applications/Tucked.app` via `scripts/install-mac.sh`, which the
  combined script calls. iPhone and iPad installs are unchanged.
- Installed the Mac app as `Tucked.app` rather than `BookmarkCollections.app`.
  Finder and Spotlight match applications on the bundle's file name, not
  `CFBundleDisplayName`, so searching "Tucked" previously found nothing.
- Scoped `scripts/reset-ui-tests.sh`'s `pkill` pattern to DerivedData paths so
  resetting the UI suite can no longer kill the installed `/Applications` copy.

### Added — 2026-07-23

- Added Save to Tucked to macOS Share menus using the existing multiplatform Share extension, with link, text-link, and image capture.

### Changed — 2026-07-23

- Changed the macOS **Save to Tucked** Share action to Quick Save: shared
  links and images now save immediately with no collection and Favorite off,
  avoiding the nested Collection menu inside Safari's Share surface. The
  interactive iPhone and iPad Share Sheet is unchanged.

### Added — 2026-07-19

- Curated 7-swatch accent palette (Grape, Coral, Amber, Cherry, Fern, Teal, Graphite), each a `{dark, light}` hex pair resolved per OS appearance via dynamic NSColor/UIColor (`AppAccent.swift`). Swatch key stored in `@AppStorage("accentKey")` (default Grape) and applied as `.tint` at the app root; sidebar counts now use `.tint` instead of `.secondary`. New `AccentPickerView` sheet (swatch grid, tuned-for-both-themes footnote, preview rows) reachable from a new Appearance section in Settings.
- Custom sidebar selection styling: the selected row now draws a soft accent pill (accent at 0.16 opacity, rounded rect) plus a 3pt left accent capsule bar via `listRowBackground`; row icons and counts render in the resolved `AppAccent`, titles stay `.primary` (semibold when selected). Rows are plain `Button`s writing the selection binding, kept inside `List(selection:)` so `NavigationSplitView` still pushes detail on compact iPhone widths. Fixes native macOS selection painting from the compiled asset accent instead of the runtime-picked accent by owning the row background directly. Also replaced the stale blue `AccentColor` asset (#2E86FF) with the Grape pair (#8A4FE0 light / #B388FF dark). UI-test `destinationElement` helper updated to wait on Button rows.

### Fixed — 2026-07-19

- Unified the library grid's adaptive column band across platforms. Mac and iOS/iPad previously used divergent ranges (Mac 220–320, iOS/iPad 160–260), producing a ~100pt "sawtooth" in card size as the window resized and making Mac/iPad density feel inconsistent. Both platforms now share `.adaptive(minimum: 160, maximum: 210)`; spacing stays platform-specific (14 iOS / 18 Mac). The minimum floor is held at 160 to preserve 2-column layout on iPhone SE (375pt width), so the band was narrowed by lowering the max rather than raising the min.
- Fixed a torn/cropped "window shade" artifact in the library grid during live iPadOS window resizing. `LazyVGrid` cells were retaining stale geometry mid-drag, which `BookmarkCard`'s clipped preview area then rendered against new cell bounds. The grid's `ScrollView` is now wrapped in a `GeometryReader` with a width-bucketed `.id()` that forces `LazyVGrid` to fully rebuild cells when available width crosses a ~20pt threshold, rather than relying on in-place relayout.
- Image viewer title is now inline; image cards show their added date instead of an empty domain line.
- Viewer and Get Info sheet minimum-size frames are macOS-only; they previously forced content wider than iPhone screens, clipping toolbars. Convention going forward: min-size frames on sheets belong in `#if os(macOS)`.
- Mac Settings sheet now uses grouped form style with a larger frame (520x480, was 440x360) so sections aren't cramped.
- Bookmark menu Share sheet now has an explicit Cancel toolbar button, so the window can be dismissed without Force Quit.
- App display name now reads "Tucked" and the Share Extension reads "Save to Tucked" on device home screens; both `Info.plist` files still had the pre-rename names ("Bookmarked Bookmarks" / "Save to Bookmark Collections") hardcoded, which silently overrode the `INFOPLIST_KEY_CFBundleDisplayName` build setting since both targets have `GENERATE_INFOPLIST_FILE = NO`. Removed the now-dead, mismatched build setting from `project.pbxproj` rather than leaving it as misleading cruft.

### Verification

- Fresh 2026-07-23 verification: 52 unit tests and 10 UI tests pass on native macOS.
- Fresh 2026-07-23 iPhone 17 Pro simulator regression: the focused 14-test `ShareCaptureModelTests` suite passes. The complete iPhone simulator unit and UI suites were not rerun for the macOS Share extension work.
- Earlier, pre-2026-07-23 full-suite iPhone simulator results recorded 47 unit tests and 10 UI tests passing.
- Signed iOS app and Share Extension build and validate with matching App Group and CloudKit entitlements.
- Real-device CloudKit, Production schema, and TestFlight checks remain release gates; see `docs/verification/cloudkit-device-matrix.md`.
