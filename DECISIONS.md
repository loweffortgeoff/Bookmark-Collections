# Architecture Decisions

Significant decisions made during development, logged for future reference.

## 2026-07-18 (Local-first SwiftData with private CloudKit mirroring)

- **Decision:** Every supported device keeps a complete local SwiftData library. User mutations save to SwiftData before metadata enrichment or CloudKit work begins. CloudKit mirrors the private store rather than acting as an online API dependency.
- **Why:** Losing connectivity can't lose a valid URL if the write path never depends on the network.
- **Alternative considered:** Treating CloudKit as the source of truth (online-first) — named directly in the original design ("rather than an online API dependency") and rejected; it would make the app unusable offline and couple every save to network/CloudKit availability, unacceptable for a bookmark-capture tool meant to work instantly from the Share Sheet.

## 2026-07-18 (One collection per bookmark)

- **Decision:** A bookmark belongs to zero or one collection. Favorite is a separate, independent boolean rather than a pseudo-collection.
- **Why:** Keeps the library's organizational model predictable while still covering the primary ways people sort bookmarks.
- **Alternative considered:** Multi-label tags — rejected for v1, deferred to the Backlog in TODO.md. Multi-membership adds real UI and reconciliation complexity for a v1 that already covers the primary organization flows with single-collection + Favorite.

## 2026-07-18 (Normalized URL identity and deterministic reconciliation)

- **Decision:** Normalize tracking parameters, fragments, host casing, and default ports before comparing URL identity. Ordinary saves update or restore an existing normalized URL. When separate offline devices create conflicting records, reconciliation keeps the earliest-created UUID, ORs the Favorite flags together, takes the most recently modified title/collection, and removes the redundant record.
- **Why:** Normalization prevents the same link with different tracking params from creating duplicate bookmarks. The reconciliation rule set gives a deterministic outcome for the offline-multi-device conflict case without a server-side authority, and OR-ing Favorite means a favorite can't be silently lost by a merge.
- **Alternative considered:** none recorded — decision predates this format.

## 2026-07-18 (Soft deletion before permanent removal)

- **Decision:** Deletion first writes a `deletedAt` timestamp and moves the bookmark to Recently Deleted. Permanent deletion is a separate, explicit, confirmed action. Aged deleted records auto-purge after 30 days.
- **Why:** A soft-delete timestamp is what makes deletion synchronizable and recoverable across devices — an immediate hard delete can't be undone or safely merged if two devices see conflicting delete/edit events.
- **Alternative considered:** none recorded — decision predates this format.

## 2026-07-18 (Portable backups over proprietary archives)

- **Decision:** Two export formats: JSON as the lossless full backup (preserves identifiers and collection/Favorite structure), and Netscape bookmark HTML for interoperability with other bookmark tools. Neither includes cached preview images.
- **Why:** JSON round-trips everything the app needs to fully restore state; HTML is the de facto universal bookmark interchange format other apps can read. Preview images are derived/cache data, not source of truth, and would bloat the export for no durable benefit.
- **Alternative considered:** A proprietary/binary archive format — rejected in favor of these two open, portable formats (the decision's own title: portable backups over proprietary archives).

## 2026-07-18 (Share Extension uses the shared durable store)

- **Decision:** The Share Extension writes to the same App Group SwiftData store and CloudKit container as the main app. It reports completion only after the local repository save succeeds; metadata enrichment starts concurrently but never delays Save.
- **Why:** Guarantees the extension's "saved" confirmation is truthful — it really is in the durable store, not just queued — and keeps the save path instant even though metadata fetch can be slow or fail.
- **Alternative considered:** none recorded — decision predates this format.

## 2026-07-18 (System UI and no external dependencies)

- **Decision:** Use only system SwiftUI/Apple frameworks for navigation, forms, import/export, sharing, alerts, commands, and accessibility. No third-party libraries, analytics/telemetry SDKs, custom accounts, or non-CloudKit sync servers.
- **Why:** Matches the standing Low Effort Apps privacy-first, no-dependency policy — smaller maintenance surface, no vendor lock-in, no data leaves Apple's ecosystem.
- **Alternative considered:** none recorded — decision predates this format (mirrors a standing cross-project policy rather than a one-off in-project tradeoff).

## 2026-07-18 (Honest sync health)

- **Decision:** Settings shows CloudKit account availability and actionable lookup errors only — never a fabricated "last synced at" timestamp.
- **Why:** CloudKit doesn't expose a trustworthy app-level "everything is synced" signal, so displaying one would just be a plausible-looking lie.
- **Alternative considered:** Displaying an approximate/best-guess last-sync timestamp anyway — named directly in the original text ("never invents last-sync evidence") and rejected.

## 2026-07-19 (Width-bucketed `.id()` to defeat stale LazyVGrid cell geometry on iPadOS resize)

- **Decision:** Wrap the library grid's `ScrollView` in a `GeometryReader` and key `.id(Int(proxy.size.width / 20))` on it, forcing `LazyVGrid` to fully discard and rematerialize its cells once available width crosses a ~20pt bucket, instead of relying on `LazyVGrid` to relayout existing cells in place.
- **Why:** iPadOS 26's continuous freeform window resizing does not reliably re-propose a fresh width to already-materialized `LazyVGrid` cells; mid-drag, cells retain stale geometry. Because `BookmarkCard`'s preview area is `Color.clear.aspectRatio(16/9, contentMode: .fit).overlay { preview }.clipped()`, that stale geometry gets clipped against the new cell bounds, producing a torn "window shade" artifact. Confirmed iPadOS-only (not Mac) on a physical iPad Pro 11" (M5) running iPadOS 26.5, and confirmed pre-existing — not a regression from the same-day column-band unification (see git history / user confirmation, 2026-07-19).
- **Alternative considered:** A coarser bucket — rejected, risks visible bucket-boundary snapping. Invalidating on every width change — rejected, defeats the purpose of `LazyVGrid` cell reuse. The 20pt bucket is a conservative, untested-at-finer-granularity starting point; revisit if resize still feels janky (tracked in TODO.md Backlog).

## 2026-07-19 (Image bookmarks ride the existing Bookmark model)

- **Decision:** Image-kind bookmarks reuse the existing `Bookmark` model via a `kind` field (`link`/`image`) rather than a separate `SavedImage` model. Image bytes live in the existing `previewImageData` field; `urlString`/`normalizedURLString` are empty for image bookmarks.
- **Why:** Collections, favorites, soft delete, CloudKit sync, and existing queries work unchanged. `kind` is a CloudKit-safe additive field with a default, so it doesn't require a schema migration story beyond the usual additive-field handling.
- **Alternative considered:** A separate model for images — rejected for duplicating the entire lifecycle machinery (collection membership, favorite, soft delete, CloudKit mirroring, query/sort plumbing) for a second time.
- **v1 consequence:** JSON/HTML export and import predate `kind` and only handle URLs, so image bookmarks are excluded from both export formats until an image-capable backup format is designed (tracked in TODO.md Backlog).

## 2026-07-19 (Curated accent palette)

- **Decision:** Ship a curated 7-swatch accent system (Grape, Coral, Amber, Cherry, Fern, Teal, Graphite) — swatch key stored, `{dark, light}` pair resolved per theme, text stays neutral — with Graphite as the default and native `List` selection for v1.
- **Why:** Free color wells let users pick unreadable accents; pre-tuned pairs guarantee contrast in both themes; Graphite is the understated, most-native default.
- **Alternative considered:** A free color well with a per-theme contrast clamp (lighten on dark / darken on light) — rejected as more machinery for a worse curated feel. Also deferred: custom pill+left-bar sidebar selection styling from the Tucked mockups (tracked in TODO.md Backlog).

## 2026-07-19 (v1 image capture is iOS-only)

- **Decision:** v1 image capture is iOS-only via the share extension; the Mac views synced images but cannot capture them.
- **Why:** The share extension target is iOS-only (always has been), Mac capture paths (drag-and-drop, file importer) are separate work, and shipping a clean iOS capture path now beats holding the feature.
- **Alternative considered:** Adding Mac drag-and-drop import to the branch — deferred to Backlog to keep v1 tight.

## 2026-07-19 (Grape as default accent)

- **Decision:** The out-of-box accent default is Grape, not Graphite.
- **Why:** Device verification confirmed the code-review concern — Graphite's gray tint makes button text read as disabled. Grape is the on-brand icon purple and reads unambiguously interactive.
- **Alternative considered:** Keeping Graphite (the design frame's "most-native" pick) — rejected after seeing it on device; Graphite remains available in the picker.

## 2026-07-19 (Sidebar pill selection)

- **Decision:** Replace native sidebar selection with the custom accent pill (Buttons writing the selection binding inside `List(selection:)`, custom `listRowBackground`); also retire the stale blue `AccentColor` asset in favor of the Grape pair.
- **Why:** macOS native selection paints from the compiled asset accent and can't follow the runtime accent, so any non-blue accent clashed; owning the row background is the only way selection follows `AppAccent`.
- **Alternative considered:** Keeping native selection and only updating the asset to Grape — rejected because selection would still ignore the user's chosen accent. Accepted losses (macOS sidebar keyboard nav, pressed/hover affordance) tracked in TODO.md Backlog.
