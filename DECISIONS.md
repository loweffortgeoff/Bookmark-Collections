# Architecture Decisions

Significant decisions made during development, logged for future reference.

## 2026-10-23 (Verified lifetime transactions deliver access)

- **Decision:** Apply verified lifetime purchase/update transactions before finishing them. Use the latest verified transaction, including its revocation state, for startup and restore. Close the paywall when access becomes unlocked.
- **Why:** Local Mac testing exposed an empty `currentEntitlements` projection for about 0.7 seconds after a verified purchase. Reading that projection once left access locked; product-catalog availability must also remain independent of ownership.
- **Alternative considered:** Wait or retry the projection before granting access. Rejected because the verified lifetime transaction already provides the required ownership evidence.

## 2026-10-23 (The Mac share view sets its own size)

- **Decision:** The macOS `ShareViewController.loadView` creates its view with an explicit 360 x 200 frame. Mac failure screens use a plain-stack `MacShareFailureView` inside that frame. One `Color(nsColor: .windowBackgroundColor)` background is applied where the controller hosts SwiftUI content. The iOS `ShareStoreFailureView` stays under `#if os(iOS)`.
- **Why:** Mac Share ▸ "Save to Tucked" looked like a silent failure. Two causes. First, the free-bookmark limit (10 active) blocked the saves: the TestFlight build read Pro as locked. The likely reason is that the earlier test purchase went through the local `Tucked.storekit` file, which does not carry to TestFlight (not confirmed). After a TestFlight sandbox purchase, saves worked, so the share code had not regressed. Second, the failure was invisible: `loadView` created `NSView()` with a zero frame and set only `preferredContentSize`, and ShareKit does not size the view from it. The log showed `view={{0, 0}, {0, 0}}`, so nothing was visible and Safari only dimmed. With the frame set, the log shows `{{0, 0}, {360, 200}}` and the failure card draws. `MacShareFailureView` is the version seen drawing and fits 200 pt. `ContentUnavailableView` was never tried at that size and would probably need more height.
- **Alternative considered:** Raising or floating the share window. Rejected, and do not retry: ShareKit resets the window level within 0.3 ms, the extension window reports not-on-screen even on a normal share, and the view is drawn remotely in Safari. An offscreen `ImageRenderer` test suggested `ContentUnavailableView` draws nothing, but that was a limit of `ImageRenderer`, not the cause.

## 2026-09-21 (The Mac app needs outgoing network access)

- **Decision:** Set `ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES` for the
  `BookmarkCollections` target. Xcode then emits
  `com.apple.security.network.client` for the sandboxed macOS app.
- **Why:** The main app fetches link metadata with `LPMetadataProvider`. With
  outgoing network disabled, every Mac fetch failed, so Mac-created bookmarks
  showed a blank preview and a domain-only title. The previews that did appear
  on Mac came from iOS enrichment or the Share Extension over CloudKit. The
  Share Extension already declared the entitlement, which is why share-sheet
  saves kept their previews.
- **Alternative considered:** Let iOS own all enrichment and keep the Mac app
  offline — rejected because the Mac is a first-class platform and must
  populate its own previews.

## 2026-09-21 (Failed metadata is retryable, and empty metadata never clears a preview)

- **Decision:** `MetadataEnricher` retries a `.failed` link after one hour, and
  it fetches never-fetched `.pending` links before retries. A successful fetch
  that returns no preview or favicon keeps the stored image instead of clearing
  it.
- **Why:** LinkPresentation fails transiently (timeouts, `LPErrorDomain`
  "Frame load interrupted", rate limits). The old code marked such a link
  `.failed`, and `enrichPending` only selected `.pending`, so one temporary
  failure left the bookmark blank permanently. In a real library, six of seven
  blank link previews fetched successfully on the next attempt. Many pages also
  have no `og:image`, so a nil image is a normal result, not a reason to erase a
  good preview.
- **Alternative considered:** Retrying every failed link on every scene
  activation — rejected because it refetches dead URLs on each launch and
  rewrites `lastMetadataRefreshAt` each time. An `og:image` HTML fallback for
  pages LinkPresentation cannot preview is a separate change, not part of this
  retry fix.

## 2026-08-30 (Distribution product uses the public app name)

- **Decision:** Keep the Xcode target, bundle identifier, and Swift module as
  `BookmarkCollections`, but set the app product name and executable to
  `Tucked`. The archive now contains `Tucked.app`.
- **Why:** macOS TestFlight and LaunchServices use the packaged application
  name for the Applications/Launchpad entry. `CFBundleDisplayName` and
  `CFBundleName` already said Tucked, but the package was still
  `BookmarkCollections.app`.
- **Alternative considered:** Change only another Info.plist name — rejected
  because the archive path would remain `BookmarkCollections.app`.


## 2026-08-29 (Share storage failures are safe for people, detailed for debugging)

- **Decision:** Keep the underlying shared-store error in local logs. Show a safe recovery message in the Share extension instead of raw storage details.
- **Why:** Raw SwiftData and CloudKit errors are not useful in a Share Sheet. The local log preserves the evidence needed to diagnose a real failure.
- **Alternative considered:** Expose the technical error in the Share Sheet. Rejected because it leaks implementation details without telling the person what to do.

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

## 2026-07-23 (One multiplatform Share extension)

- **Decision:** The existing Share extension target supports both iOS and macOS. It keeps platform-specific UIKit/AppKit hosting and signing configuration around one shared capture model, form, repository save path, App Group store, and CloudKit container. This supersedes the 2026-07-19 decision that v1 image capture is iOS-only: links, text links, and images can now be captured from Share surfaces on both platforms.
- **Why:** The accepted inputs and durable local-first save semantics are the same on both platforms. Sharing the target keeps URL normalization, image downsampling, Collection/Favorite behavior, and completion-after-persistence rules aligned without duplicating product logic.
- **Alternative considered:** Separate iOS and macOS Share extension targets — rejected because their only meaningful differences are host-controller and platform-signing details; separate targets would duplicate the capture UI and create two persistence paths that could drift.

## 2026-07-23 (macOS Share uses capture-first Quick Save)

- **Decision:** On macOS, choosing **Save to Tucked** immediately saves the
  shared link or image with no collection and Favorite off. The extension may
  show brief progress and exposes Retry/Cancel only after failure. iOS and
  iPadOS retain the interactive Collection and Favorite form.
- **Why:** Safari hosts the extension in a ShareKit-owned system dialog, so
  the Collection picker becomes a native menu nested inside Safari's Share
  interaction. Live verification showed that the menu functions but the
  layered interaction is awkward and is not Debug-specific. Tucked already
  persists directly into the shared App Group store, so capture can finish
  without launching the containing app.
- **Alternative considered:** Keep full cross-platform UI parity — rejected
  because the macOS host interaction is needlessly layered. Add a preference
  or a second Share action — rejected as extra settings/target complexity for
  a capture path intended to be immediate.

## 2026-07-25 (The Mac gets its own install script, installing to /Applications)

- **Decision:** macOS installs through `scripts/install-mac.sh`, which builds,
  copies the product to `/Applications/Tucked.app`, prunes dead LaunchServices
  registrations, re-registers the installed path, and launches from there.
  `scripts/install-all-devices.sh` calls it instead of carrying its own Mac
  branch. The bundle is installed as `Tucked.app`, not `BookmarkCollections.app`.
- **Why:** The Mac branch built and then `open`ed the product in place from
  `build/DerivedData`. That is a launch, not an install: it is the same shape as
  the iPhone/iPad branch minus the `devicectl device install` step. The only
  copy therefore sat in a build directory, where the next rebuild, a macOS UI
  test run, or `scripts/reset-ui-tests.sh` removed or replaced it — which is why
  the Mac app "stopped running after about a day" and had to be relaunched from
  Xcode. Nothing was expiring; the signing certificate and provisioning profile
  were valid for another year. The `Tucked.app` file name is required separately:
  Finder and Spotlight match applications on the bundle's file name, and
  `CFBundleDisplayName` alone does not make "Tucked" findable.
- **Alternative considered:** Parameterizing the combined script's Mac branch —
  rejected, the branch was structurally wrong rather than mistuned. Building the
  Mac install as Release to escape the bundle-id collision with the macOS UI test
  suite — rejected for now because Release signs into the Production CloudKit
  environment, whose schema is not yet deployed; `scripts/reset-ui-tests.sh` was
  scoped to DerivedData paths instead. Revisit `CONFIGURATION=Release` once the
  Production schema ships.

## 2026-07-30 (Untuck: lastOpenedAt + Forgotten filter destination)

- **Decision:** Approach A — additive `lastOpenedAt`, Forgotten as `LibraryDestination`,
  Surprise me from current visible set; pure `UntuckRules` for membership/candidates.
- **Why:** Anti-hoard surface with minimal architecture; expandable to a hub sheet later.
- **Alternative considered:** Untuck hub sheet first (B); age-only without open tracking.

## 2026-08-12 (Native system accent)

- **Decision:** Remove the curated accent palette, Settings → Appearance, and custom sidebar pill selection. Use the platform accent and native `List` selection.
- **Why:** The picker forced custom selection chrome that felt less native than the rest of the app.
- **Alternative considered:** Keep Grape as a compiled `AccentColor` with no picker — rejected; that is still an app-owned color rather than the system accent.
- **Supersedes:** 2026-07-19 Curated accent palette, Grape as default accent, and Sidebar pill selection. Leave those entries in place and treat this one as current.

## 2026-08-28 (Snippets reuse the bookmark model rather than getting their own)

- **Decision:** A snippet is a `Bookmark` with `kind == .text`, a `snippetBody`, and an empty `normalizedURLString`. It is not a separate SwiftData model.
- **Why:** Every library behavior a snippet needs already exists on `Bookmark`: collections, Favorite, soft delete, Recently Deleted, Forgotten, search, sorting, and CloudKit mirroring. A second model would have had to reimplement all of it and then be merged back at every destination. The empty normalized URL is what keeps snippets out of link de-duplication, and image bookmarks already rely on the same trick.
- **Alternative considered:** A separate `Snippet` model with its own repository. Rejected: it doubles every destination, every sort, and every backup path for one differing field.

## 2026-08-28 (Opening a snippet opens its editor, and that counts as opening it)

- **Decision:** Opening a snippet presents `SnippetEditorView` and calls `markOpened`.
- **Why:** A snippet has nowhere else to open. Making the editor the viewer avoids a read-only surface that duplicates the editor's layout. The `markOpened` call is not cosmetic: without it, a snippet read every week still falls into Forgotten after 30 days and can never leave, because Forgotten keys on `lastOpenedAt` being nil.
- **Alternative considered:** A separate read-only snippet viewer, matching `ImageViewerView`. Rejected: an image viewer earns its own surface because zoom and full-screen are not editing affordances. Text has no equivalent.

## 2026-08-29 (A custom selection-bar "container" that looks oversized is the background, not the buttons)

- **Decision:** `LibraryGridView`'s multi-select bottom bar (`selectionBar`) dropped its `.background(...)` entirely and switched from fixed `HStack(spacing:)` to `Spacer()`-separated full-width icons. It also switched to icon-only labels (`.labelStyle(.iconOnly)`) and `.buttonStyle(.plain)`, fixing an earlier bug where text labels wrapped into a letter-stack ("Fa/vo/rit/e") under space pressure.
- **Why:** Once the labels were icon-only, the bar still looked "too large" to the eye. Four rounds of shrinking the outer `.padding()` (18/10 → 14/6 → 10/4) and adding `.buttonStyle(.plain)` produced **zero visible change on a live device**, each verified on the correct branch with a clean build and fresh install. That null result was the actual signal, not noise: a diagnostic swap to an extreme `.padding(40)` + `Color.red` background *did* visibly balloon, proving the build pipeline was fine and ruling out "stale build" as the explanation. A follow-up diagnostic (same small padding, `.bar` material swapped for a plain `Color`) rendered identically, ruling out the material itself. The real cause was never padding, button style, or background material — it was that a `.background(...)` on the HStack draws a visible card sized to the group's total footprint (which includes each button's own ~44pt minimum tap target), and *any* visible card around correctly-sized icon buttons reads as "a big gray box." Removing the background outright, so the icons float directly over content with no card to look oversized, fixed it immediately — no button-level frame override needed.
- **Alternative considered:** Overriding each button's `.frame()` below Apple's 44pt minimum touch-target guideline to force the visible box smaller — this was raised as the last remaining lever once padding/style/material were eliminated, but rejected as an accessibility trade-off, and turned out to be unnecessary once the actual culprit (the background itself) was found.
- **Note for next time:** This exact "custom icon toolbar looks oversized" symptom was suspected to have been hit and fixed before in another Low Effort Apps project (Task(ed), AisleWise/List-Happens, or Muzzletoff/EveryPaw), but a search of all three repos' current code, docs, and full git history turned up no matching fix or even a bottom selection toolbar at all. This entry exists so the next occurrence — in this repo or another — has an actual example to find: check for an unnecessary `.background(...)` behind icon-only buttons before touching padding, spacing, or tap-target size.

## 2026-08-29 (Ten free active bookmarks, then one lifetime unlock)

- **Decision:** Tucked allows 10 active bookmarks for free, then offers Tucked for Life as a $4.99 universal non-consumable purchase. Links, images, and snippets share the same cap; deleting frees a slot. Export and existing-bookmark access remain free.
- **Why:** Ten saved items gives a practical trial without a subscription or a time-limited trial. A single purchase keeps the product and support surface small across iPhone, iPad, and Mac.
- **Alternative considered:** A one-week free trial or separate per-platform unlocks — rejected. The free library already lets people evaluate the app, and universal purchase avoids asking the same customer to buy Tucked for Life again on another device.
- **Release handling:** Beta archives compile with the cap disabled. Release archives compile with it enabled. The app does not infer TestFlight status from a receipt.

## 2026-10-15 (Revive the paywall at $4.99 with a new product ID)

- **Decision:** The paywall branch is rebased onto v1.0 `main`. The price drops from $7.99 to $4.99. The product ID changes to `com.loweffortapps.BookmarkCollections.tuckedforlife`. "Tucked Pro" wording becomes "Tucked for Life".
- **Why:** The first IAP was deleted in App Store Connect, and Apple does not let a deleted Product ID be created again. v1.0 has no users other than the owner, so nobody needs an existing-user exemption and the paywall can land before the first public release.
- **Alternative considered:** Keep $7.99. Rejected by the owner in favor of an impulse-friendly one-time price.
- **Also:** The paywall copy leads with support for an independent developer (a fifth row) and adds a footnote that existing bookmarks stay accessible. The App Store Connect IAP review screenshot is the iPhone 6.9" paywall captured with `Tucked.storekit` attached to a run of `Tucked Release`.
