# Tucked TODO

## Next

_Nothing in flight._

The remaining v1 release gates (real-device CloudKit matrix, Production schema, TestFlight/new-account check) are tracked in `docs/verification/cloudkit-device-matrix.md`, not here.

## Backlog

The deferred Photos picker, Files importer, and drag-and-drop items below are alternate in-app import paths, not missing Share Sheet support; macOS and iOS Share surfaces already capture images.

- The library grid's width-bucketed `.id()` relayout workaround (2026-07-19) uses a 20pt bucket, chosen conservatively without testing finer granularity. Revisit if resize still feels janky or visible bucket-boundary snapping shows up.
- Watch for the same stale-cell-geometry pattern (iPadOS 26 continuous window resize not re-proposing width to already-materialized cells) if other adaptive/resizable grid or list layouts are added later.
- Switch `scripts/install-mac.sh` to `CONFIGURATION=Release` once the Production
  CloudKit schema is deployed. Release drops `get-task-allow` and the
  `testmanagerd` temporary exceptions, and takes the daily-driver Mac copy out
  of the bundle-id collision with the macOS UI test suite. Blocked today because
  Release signs into the Production CloudKit environment.
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
- Untuck hub sheet (approach B) on top of `UntuckRules`.
- Configurable Forgotten threshold / Settings control.
- “Not opened in 30 days” re-entry (opened once, then stale again).
- Sort by last opened.
- Production CloudKit schema deploy for `lastOpenedAt` before Production-signed Untuck release (if not already done at ship time).

### Product differentiation ideas (2026-07-30)

Captured during the post-v1 uniqueness brainstorm. Untuck (Forgotten + Surprise me) shipped first. These are the next bets to consider, not committed work. Prefer one clear bet at a time over a feature pile. Full design only when one is picked.

- **Visual tuck (OCR / screenshot research)** — Strongest long-term moat around image-kind bookmarks. On-device Vision OCR so screenshots are searchable; optional “links found in this image.” Positioning: save what you *saw*, not only the URL. Privacy-fit (no cloud AI). Rough size: 1–2 weeks for a useful v1.
- **Why I tucked this** — Lightest product experiment. Optional one-line intent at capture or edit (“gift idea”, “for the trip”); filter/search by it. Complements single-collection + Favorite without tags. Rough size: 3–5 days.
- **Private boards (presentation, not new model)** — Collections as mixed-media boards (links + screenshots). Full-bleed / collage browse per collection; private Pinterest energy without social. Mostly UX on the existing `kind` model. Rough size: 1–2 weeks for a first collage surface.
- **On-device smart tuck** — Local-only helpers after the above: similar saves, collection suggestions from title/OCR, dead-link check on open. Apple frameworks only; no third-party AI APIs. Do after Visual tuck or Untuck has more usage signal. Rough size: 2+ weeks.
- **Untuck hub sheet (B)** — Already listed above. Branded shell on `UntuckRules` (~1–2 days) if Forgotten/Surprise need a stronger discoverability moment.

**Deprioritize / skip for now** (crowded or fights brand): multi-label tags as the main differentiator, browser extensions, collaborative/social collections, full offline page archives, cloud “AI summarize every page.”

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

- [x] Give the Mac a real install step: `scripts/install-mac.sh` installs to
      `/Applications/Tucked.app` instead of launching the build product in
      place, so the app survives a rebuild and shows in Spotlight (2026-07-25).

- [x] Decide accent default: moved from Graphite to Grape after device verification — gray-tinted buttons read too close to disabled (2026-07-19).
- [x] Custom sidebar selection styling (soft tinted pill + left accent bar) from the Tucked mockups (2026-07-19).
- [x] Reconsider the accent picker's Preview rows if pill styling never ships — resolved: pill styling shipped, so the picker preview now matches the real sidebar (2026-07-19).
