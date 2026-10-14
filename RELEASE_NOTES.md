# Release Notes — v1.0

Theme: Save links, images, and text snippets in one native library across iPhone, iPad, and Mac, with tools that bring forgotten saves back into view.

## NEW

- Save links, images, screenshots, and text snippets in a single library for iPhone, iPad, and Mac.
- Save from anywhere with **Save to Tucked**: the iPhone and iPad Share Sheet lets you pick a Collection and mark Favorite before saving, while the macOS Share menu saves immediately in one click.
- Import images directly on Mac with `File ▸ Add Images…` and view any saved image in a full-screen zoomable viewer.
- Create text snippets in the app with an optional source URL, a card excerpt preview, full-text search across snippet bodies, and one-tap Copy Text.
- Organize items with single-membership Collections and an independent Favorites filter, with live item counts in the sidebar for All Items, Images, Links, Snippets, Favorites, and each collection.
- Surface neglected saves with **Forgotten** (never-opened items older than 30 days) and **Surprise me** (opens a random item from your current view).
- Inspect item metadata in the **Get Info** panel: title, URL, collection, Favorite status, and added, modified, and last-opened dates.
- Keep your library portable with versioned JSON backup and restore (including snippets and open history), plain-text URL import, and Netscape-compatible HTML bookmark export.
- Recover removed items from **Recently Deleted** for up to 30 days before permanent removal.
- Mirror your library across iPhone, iPad, and Mac with local-first storage and automatic duplicate URL reconciliation.

## IMPROVED

- Unified the responsive card grid across iPhone, iPad, and Mac, with smooth cell relayout during continuous iPadOS window resizing.
- Adopted native system accent colors and standard sidebar selection across platforms, paired with full Light and Dark appearance, Dynamic Type scaling, VoiceOver card labels, and macOS keyboard shortcuts.
- Simplified the multi-select bottom bar to evenly spaced icon-only actions so labels never stack or wrap on compact screens.

## FIXED

- Link metadata fetches now retry after temporary network failures and preserve existing preview images when a refresh returns no image.
- Enabled outbound network access in the sandboxed Mac app so links saved on Mac fetch titles and preview images directly.
- Share Extension storage errors now present a clear recovery message and log diagnostic details locally.
- Packaged the Mac app as `Tucked.app` and updated the macOS application menu title so Finder, Spotlight, Launchpad, and TestFlight all display **Tucked**.

## What to Test — 1.0

- **iOS/iPadOS Share Sheet:** Share a webpage from Safari and an image from Photos. Pick a Collection, toggle Favorite, and tap Save. Confirm both appear immediately in Tucked.
- **macOS Quick Save:** Share a link from Safari and an image from Finder using **Save to Tucked**. Confirm the save completes immediately with no Collection and Favorite off, even when Tucked is closed.
- **Mac Image Import:** Use `File ▸ Add Images…` (`⌘⇧I`) on Mac to import one or more images, then open an image card to test the full-screen zoomable viewer.
- **Snippets:** Create a text snippet with and without a source link. Test searching for a word inside the snippet body, copying the snippet text, and opening the source link.
- **Untuck flows:** Confirm **Forgotten** lists only never-opened items older than 30 days. Open an item (link, image, or snippet) and verify `Last Opened` updates in **Get Info** and removes the item from Forgotten. Tap **Surprise me** in the toolbar to open a random visible item.
- **Backup & Export:** Export a JSON backup from Settings, restore it, and verify collections, Favorites, snippets, and dates remain intact. Test plain-text URL import and HTML export.
- **iCloud Sync:** Verify cross-device sync across iPhone, iPad, and Mac. Remaining manual checks from `docs/verification/cloudkit-device-matrix.md` include Mac-originated create-bookmark sync, offline conflict resolution, airplane-mode Share Sheet capture, and the fresh-account Production sync check.
