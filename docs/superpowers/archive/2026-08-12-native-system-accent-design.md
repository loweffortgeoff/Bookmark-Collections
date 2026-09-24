# Native system accent

Date: 2026-08-12
Status: approved design, not yet implemented
Branch: `native-system-accent`

## Problem

Settings → Appearance lets the user pick one of seven curated accents. The
sidebar then draws a custom pill + left bar so selection can follow that
runtime color. Native macOS list selection cannot, which is why those pills
existed.

The custom chrome is the part that feels off. Dropping the picker without
dropping the pills would leave a workaround with nothing to work around.

## Decision

Remove in-app accent selection and custom sidebar highlighting. Tint and
selection come from the system.

This supersedes the 2026-07-19 decisions: curated accent palette, Grape as
default, and sidebar pill selection.

## Behavior

**Accent**

- The app does not offer an accent picker.
- The app does not compile a custom `AccentColor` (currently the Grape pair).
- The app does not apply a root `.tint(...)`.
- **Mac:** buttons, links, and selected-row chrome follow System Settings →
  Appearance → Accent color.
- **iPhone / iPad:** the same controls use Apple’s default system blue. iOS
  has no user-wide accent picker comparable to macOS.
- A leftover `accentKey` value in `UserDefaults` is ignored. Do not migrate
  or delete it.

**Sidebar**

- Rows are native tagged `Label`s inside `List(selection:)`.
- Selection is the system sidebar highlight.
- Counts stay as `.badge`.
- Compact iPhone still pushes the detail column when the selection binding
  changes (`List(selection:)` stays).
- The Collections header plus-button and empty-state “Create Collection”
  button stay as buttons. They are actions, not destinations.
- Context menus on collection rows stay.
- Accessibility identifiers stay (`destination.allItems`,
  `destination.collections` on the first collection, and so on).

**Settings**

- The Appearance section is gone.
- Library Data and iCloud sections are unchanged.

**Unchanged**

- App icon (Dusk Candy / Grape).
- Light / dark follows the system. There is no appearance override today
  and this work does not add one.
- Share extension, capture, library, import/export.

## Implementation

Delete:

- `BookmarkCollections/Features/Appearance/AppAccent.swift`
- `BookmarkCollections/Features/Appearance/AccentPickerView.swift`
- `BookmarkCollections/Assets.xcassets/AccentColor.colorset/`

The Features tree is a synchronized Xcode group. Deleting those Swift files
is enough; no file-ref edits in `project.pbxproj`.

Edit:

- `BookmarkCollectionsApp.swift` — drop `@AppStorage` accent key and the
  root `.tint(AppAccent...)`.
- `SettingsView.swift` — drop the Appearance section, accent sheet,
  `accentKey`, and `isPickingAccent`.
- `CollectionListView.swift` — replace `SidebarRow` with tagged `Label`
  rows; drop `AppAccent` / `@AppStorage`.
- `project.pbxproj` — delete the
  `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;`
  lines on the app target (both Debug and Release). Do not leave the
  key set to an empty string. Leaving it pointed at a missing
  `AccentColor` would keep a compiled override or a build warning.

UI tests:

- `destinationElement` currently queries `app.buttons`. Native list rows
  are not reliably buttons on both platforms. Point it at the existing
  `identified()` helper (any descendant with that identifier) and wait
  for existence.
- Identifiers and flows stay the same. No new UI test for a removed
  settings row.

Docs (same change, same commit as the code unless the plan splits them):

- `README.md` — remove the curated-palette sentence and the Appearance
  mention in Architecture.
- `CHANGELOG.md` — record the removal under Unreleased.
- `DECISIONS.md` — log this reversal and point at the three 2026-07-19
  entries it supersedes.
- `TODO.md` — close the macOS sidebar keyboard-nav and hover-affordance
  backlog items. Native `List` restores both.

## Testing

1. Unit tests: `BookmarkCollectionsTests` on macOS. Accent code has no
   unit suite; this is a regression check.
2. UI tests: `BookmarkCollectionsUITests` on macOS. Sidebar navigation
   must still reach All Items, Favorites, Forgotten, the first
   collection, and Recently Deleted.
3. Manual, Mac: selected sidebar row uses the system accent; changing
   System Settings → Accent updates Tucked after a relaunch (live
   follow is nice if the system does it; relaunch is enough).
4. Manual, iPhone or simulator: Settings has no Appearance section;
   sidebar uses native selection; tint is system blue.

## Out of scope

- Changing the app icon.
- Per-platform accent (Grape on iOS, system on Mac).
- Cleaning `accentKey` out of existing UserDefaults.
- Website / marketing copy.

## Success

Opening Tucked looks like a system app: no Appearance settings, no custom
sidebar pills, tint matches the platform default.
