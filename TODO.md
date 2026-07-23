# Tucked TODO

## Next

_Nothing in flight._

The remaining v1 release gates (real-device CloudKit matrix, Production schema, TestFlight/new-account check) are tracked in `docs/verification/cloudkit-device-matrix.md`, not here.

## Backlog

The deferred Photos picker, Files importer, and drag-and-drop items below are alternate in-app import paths, not missing Share Sheet support; macOS and iOS Share surfaces already capture images.

- The library grid's width-bucketed `.id()` relayout workaround (2026-07-19) uses a 20pt bucket, chosen conservatively without testing finer granularity. Revisit if resize still feels janky or visible bucket-boundary snapping shows up.
- Watch for the same stale-cell-geometry pattern (iPadOS 26 continuous window resize not re-proposing width to already-materialized cells) if other adaptive/resizable grid or list layouts are added later.
- Photos-picker in-app image import.
- Files-importer image import (Mac).
- Drag & drop image import onto the library grid (Mac/iPad).
- `pageDescription` field + og:description fetch for the info panel.
- Image bookmarks are excluded from JSON/HTML export; design image-capable backup.
- Encode shared photos as JPEG/HEIC instead of PNG (CloudKit payload size).
- Make macOS menu commands kind-aware for image bookmarks (Open silently no-ops, Share shows "URL invalid").
- `BookmarkEditorView` still applies `minWidth` 380 unconditionally — wrap in `#if os(macOS)` like the newer sheets.
- macOS sidebar keyboard navigation (arrow keys/type-select) lost when sidebar rows became untagged Buttons — restore if it proves annoying.
- Sidebar rows have no pressed/hover affordance with `.plain` button style — consider a hover highlight on macOS.

## Deferred Beyond v1

These items were explicitly excluded from v1 and are not release blockers or committed roadmap work:

- Tags and multi-label organization.
- Offline webpage archives, reader mode, and standalone image storage.
- Shared or collaborative collections.
- Browser extensions.
- Custom accounts or non-CloudKit sync servers.
- Analytics or telemetry SDKs.
- StoreKit monetization.

## Done

_Earlier v1 work landed before TODO.md tracked completions with dates._

- [x] Decide accent default: moved from Graphite to Grape after device verification — gray-tinted buttons read too close to disabled (2026-07-19).
- [x] Custom sidebar selection styling (soft tinted pill + left accent bar) from the Tucked mockups (2026-07-19).
- [x] Reconsider the accent picker's Preview rows if pill styling never ships — resolved: pill styling shipped, so the picker preview now matches the real sidebar (2026-07-19).
