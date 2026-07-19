# Link Info Panel + Image Import — Design

Date: 2026-07-19
Status: Approved (brainstorm session)

Two features for Tucked, designed together because the second introduces a new
item kind that the first must accommodate.

## Feature 1 — Link Info Panel

An inspector-style information panel for a bookmark, opened from the context
menu (not a tap gesture, to avoid disturbing existing tap/context-menu
behavior).

### Entry point

- New **Get Info** item in `BookmarkActions` (SF Symbol `info.circle`),
  placed above Favorite.
- Shown for normal items only — not in Recently Deleted.

### Presentation

- A **sheet on all platforms** (iPhone, iPad, Mac), presented from
  `LibraryRootView` via a new `sheet(item:)` binding — same pattern as the
  existing Edit sheet.

### Contents (top to bottom)

1. **URL row** — full URL, tappable to open in the browser, with a copy
   button. Hidden for image-kind items (Feature 2).
2. **Title card** — the stored title.
3. **Organization** (interactive):
   - Collection picker row, reusing the same collection list the Edit/Move
     flows use.
   - Favorite toggle.
   - Changes save immediately through the repository and update `modifiedAt`.
4. **Details** (read-only) — Added (`createdAt`) and Modified (`modifiedAt`)
   as formatted dates.

### Explicitly out of scope (v1)

- **Page description** — Tucked stores no description; LinkPresentation does
  not provide one. Adding a `pageDescription` field + og:description fetch is
  a separate future feature.
- **Tags** — no tag system exists in Tucked.

### New files

- `BookmarkCollections/Features/Bookmark/BookmarkInfoView.swift`

No model changes for this feature.

## Feature 2 — Image Import via Share Extension

Save screenshots and images into Tucked. **Sole v1 import path: the share
extension.** (Photos picker, file importer, and drag & drop are future
candidates — see Backlog.)

### Data model

- Extend the existing `Bookmark` model rather than adding a second model, so
  collections, favorites, soft delete, CloudKit sync, and library queries all
  work unchanged.
- New field: `kind` — raw-backed string enum (`link`, `image`), default
  `link` so existing records are untouched (CloudKit-safe schema addition).
- Image bytes stored in the existing `previewImageData` field
  (`.externalStorage`, already synced).
- For image items: `urlString` / `normalizedURLString` are empty; the
  activation-time duplicate reconciliation and metadata enrichment **skip
  image-kind items**.

### Share extension

- `ShareCaptureModel` accepts `UTType.image` in addition to URLs.
- Incoming images are downsampled with the same 1200px pipeline the metadata
  provider uses, then saved as an image-kind bookmark.
- Default title: "Image — <date>" style, editable later via Edit.
- Extension UI shows a thumbnail instead of the URL line.

### Library

- New `images` and `links` cases in `LibraryDestination`, driving the
  sidebar's Images / Links filter tiles.
- Cards render the image full-bleed with the editable title below (mostly
  existing `BookmarkCard` behavior with `previewImageData`).

### Tap behavior

- Links: open in browser (unchanged).
- Images: full-screen zoomable viewer — new `ImageViewerView` with
  pinch/double-tap zoom and a ShareLink in the toolbar.

### Context menu for image items

- Shown: Favorite, Move, Edit (title/collection), Share (the image itself),
  Delete, Get Info (URL row hidden).
- Hidden: Refresh Preview and any browser-opening action.

### Testing

- Unit: kind-aware dedup and enrichment skipping; repository save of image
  items.
- UI: Images filter shows only image items.

## Build order

Feature 1 first (UI-only, no schema change), then Feature 2.
