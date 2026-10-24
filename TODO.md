# Tucked TODO

## Next

- [ ] **Review the remaining-bug spec.** [Draft spec](docs/superpowers/specs/2026-10-23-remaining-bug-fixes-design.md) and [full-send plan](docs/superpowers/plans/2026-10-23-remaining-bug-fixes.md) cover Share data preservation/storage diagnosis, accessible layouts, Mac actions, and configuration cleanup. Implementation awaits approval.

- [ ] **Device-test the approved paywall and JSON fixes.** Local implementation, all 169 checks per platform, signed Release builds, and independent review pass. TestFlight 1.0 (9) is available internally for iPhone and native Mac from `f34b8c6`; use the [JSON pack instructions](docs/verification/fixtures/2026-10-23-testflight/README.md). Before submission, verify current-build purchase/restore and cross-device access in sandbox/TestFlight, physical-device Share capture, and fresh-account Production sync. See [audit and follow-up](docs/verification/2026-10-23-branch-paywall-audit.md).

Approved work queue (2026-10-21). Things: Tucked area, Bug Fixes and Feature Work projects. Tasks have no dates. Follow the numbered order across both projects.

- [ ] **1. Diagnose the iOS Share storage failure** (Things: Bug Fixes). Reproduce the failure, read `ShareStorage` logs, identify the cause, then retest links and images after a fix.

  2026-10-23 audit: live Safari link and Photos image sharing pass in the normal iPhone 18 Pro simulator store and survive relaunch. The physical-device failure and CloudKit sync remain unverified.

  Prior investigation: reproduce the iOS Share-extension storage failure and inspect its new
  `ShareStorage` log before changing storage or entitlement configuration.
  The failure message is "Tucked could not open its shared library," and it
  blocks every share, including links and images. Highlighted-text share is
  the separate v1.1.0 item below unless that storage message is what appears.
  The 2026-10-23 macOS share fix did not resolve this iOS failure. The `ShareStorage`
  log now records the error domain and code down the underlying-error chain, which
  should make the cause diagnosable.
- [x] **2. Restore the macOS UI test runner** (Things: Bug Fixes). Confirm the current empty accessibility tree, check permissions, rerun the suite, and record the actual cause and result.

  2026-10-23 follow-up: all 15 Mac UI cases pass. Numeric free-limit launch arguments suppressed the initial window under native XCTest; filling the real ten-item cap through UI saves resolves that harness gap. Local purchase closes the paywall and shows the unlocked Settings badge.

  Prior tooling investigation: the macOS UI test suite failed wholesale (11 of 11).
  Merged `main` is byte-identical to the tree whose UI suite passed on
  2026-08-28 at 09:50, the app launches and stays alive under `-ui-testing`,
  and all code signatures are valid. The runner attaches to the app and gets a
  pid, but reads zero accessibility identifiers from it — an empty tree, not a
  missing element. Ruled out: stale runner signature, leftover processes, a
  clean DerivedData rebuild, and moving `/Applications/Tucked.app` aside.
  Leading explanation is macOS withholding Accessibility/Automation permission
  after a second binary claimed the same bundle identifier. First thing to try:
  `tccutil reset All com.loweffortapps.BookmarkCollections`, re-run the suite,
  and grant control when macOS prompts. Then check System Settings → Privacy &
  Security → Accessibility for Xcode and Terminal. Release builds drop
  `get-task-allow`, so installing Release may clear this on its own.

- [ ] **Finish verifying the Mac share failure card** (unnumbered; follow-up to the 2026-10-23 Mac share fix). On a Mac, check four things: the free-limit message text in the share sheet, light mode, the largest accessibility text size (the fixed 360 x 200 frame could clip the buttons), and the storage-failure screen. The window background is unverified: if the card looks doubled, remove the one `.background` line in `ShareViewController.host`.

  2026-10-23 audit: live Safari at the free limit shows readable message text, Cancel, and Retry in light and dark mode. Retry remains blocked; Cancel dismisses. Largest text and a live storage-failure screen remain open.

  Previously seen working: a plain-text share shows "Share a web link or an image." in dark mode with the window background. To repro the limit, edit the App Group prefs plist (`~/Library/Group Containers/group.com.loweffortapps.BookmarkCollections/Library/Preferences/group.com.loweffortapps.BookmarkCollections.plist`, key `tuckedProUnlocked`) with `plutil -replace tuckedProUnlocked -bool NO`, then `killall cfprefsd`. `defaults write` edits the wrong file because the CLI is not sandboxed. Do not open Tucked before sharing; launch rechecks StoreKit and can reset the flag. Read logs with `/usr/bin/log show --last 5m --info --predicate 'subsystem == "com.loweffortapps.BookmarkCollections"'` (full path; plain `log` is a zsh built-in). Categories: `ShareSave`, `ShareStorage`.

  > **Branch state:** not yet merged; the four checks above are pending. Squash at merge, because the history holds a removed window-raise experiment and a removed TEMP experiment.

The remaining v1 release gates (real-device CloudKit matrix, Production schema, TestFlight/new-account check) are tracked in `docs/verification/cloudkit-device-matrix.md`, not here.

## v1.1.0

After the initial release is approved. None of this blocks 1.0.

- [ ] **3. Complete the v1.1 card-style checks** (Things: Feature Work). Keep the accepted outlines, shadows, and native sidebar selection. Check Mac selection and iPad live resize.
  Prior iPhone light/dark captures and three focused UI checks passed with an iOS 18 test-build override. Mac built with temporary ad hoc signing, but its preview opened no window; Mac selection and iPad resize remain unverified.
- [ ] **4. Save highlighted text as a snippet** (Things: Feature Work). After Share storage works, test prose with and without a page URL on Mac and iOS. Save the selection as snippet text and keep the page URL as its optional source.
  The current loader rejects prose without a URL or prefers a supplied page URL and drops the selection. Confirm the actual result first. The storage error in Next is a separate failure.
  Found 2026-10-23: a plain-text selection in Safari reaches the Mac share extension with no attachments (probably the text sits in the extension item's text content, not an attachment). It is a deterministic Mac repro for the share failure card and needs no paywall state.
- [ ] **5. Fix Larger Text layout problems** (Things: Bug Fixes). Check the grid, cards, sidebar, and editor sheets at the largest accessibility text sizes on iPhone and iPad. Fix broken layouts, then reassess the Mac claim.
  Reported 2026-10-14. The 1.0 Larger Text claim covers iPhone and iPad only.
- [ ] **6. Add the Mac menu bar helper** (Things: Feature Work). After highlighted-text capture is settled, add Search, Links, Images, Snippets, Open Tucked, Settings, and Quit. Use the Stash menu as the reference; no tags.
  Add clipboard snippet capture and its keyboard shortcut only if Share capture leaves a real gap. This replaces the deferred Glaze-style quick-capture panel.

Shortcuts remains an idea from Tucked Testing. Clipboard capture is the remaining scope question; settle it from task 4 before task 6.

## Backlog

The deferred Photos picker and drag-and-drop items below are alternate in-app import paths, not missing Share Sheet support; macOS and iOS Share surfaces already capture images.

- The library grid's width-bucketed `.id()` relayout workaround (2026-07-19) uses a 20pt bucket, chosen conservatively without testing finer granularity. Revisit if resize still feels janky or visible bucket-boundary snapping shows up.
- Watch for the same stale-cell-geometry pattern (iPadOS 26 continuous window resize not re-proposing width to already-materialized cells) if other adaptive/resizable grid or list layouts are added later.
- Share failure on the free-limit screen: Retry always fails the same way. Polish: replace Retry with an "Open Tucked" action for that failure (2026-10-23).
- Re-sharing a URL that is already saved sets its collection to none and Favorite off. A Mac quick save also overwrites its favicon and preview with nil and marks metadata ready though none was fetched. Preserve the existing values on a re-share (2026-10-23).
- `PaywallEnabled` is an empty string in the share extension target's Info.plist, because `PAYWALL_ENABLED` is unset for that target. Code treats empty as enabled. Set it explicitly for the extension (2026-10-23).
- The test target's `IPHONEOS_DEPLOYMENT_TARGET` is 17.0 but the app needs 18.0, so simulator tests need an `IPHONEOS_DEPLOYMENT_TARGET=18.0` override. Raise the setting in the project (2026-10-23).
- Photos-picker in-app image import.
- Drag & drop image import onto the library grid (Mac/iPad).
- `pageDescription` field + og:description fetch for the info panel.
- Image bookmarks are excluded from JSON/HTML export; design image-capable backup.
- Encode shared photos as JPEG/HEIC instead of PNG (CloudKit payload size).
- Make macOS menu commands kind-aware for image bookmarks (Open silently no-ops, Share shows "URL invalid").
- Make the macOS Share menu command kind-aware for snippets. Share still assumes a URL, so it shows “URL invalid” for a snippet with no source link. Open already routes a snippet to the editor, and Copy Text is on the Bookmark menu.
- Sharing plain non-URL text, clipboard snippet capture, and a Mac menu bar extra are in v1.1.0 above.
- `BookmarkEditorView` still applies `minWidth` 380 unconditionally — wrap in `#if os(macOS)` like the newer sheets.
- Untuck hub sheet (approach B) on top of `UntuckRules`.
- Configurable Forgotten threshold / Settings control.
- “Not opened in 30 days” re-entry (opened once, then stale again).
- Sort by last opened.

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

## Done

_Earlier v1 work landed before TODO.md tracked completions with dates._

- [x] Privacy policy on loweffortapps.app covers the Tucked for Life purchase, and 1.0 was submitted for review with the IAP (2026-10-15). Tucked's own product page waits for launch (2026-10-16).
- [x] Tucked for Life paywall merged to `main`; Restore Purchases confirmed on a second device (2026-10-15).
- [x] Sandbox test purchase of Tucked for Life succeeded (2026-10-15).
- [x] Verified after macOS TestFlight upload that Applications and Launchpad
      entries show `Tucked` (2026-10-14).
- [x] Files-importer image import (Mac) — shipped as `File ▸ Add Images…` (2026-08-28).
- [x] Text snippets, the `snippets` key in JSON backup, and Mac image import —
      brings the Swift app back to parity with the Glaze port (2026-08-28).
- [x] Production CloudKit schema carries `lastOpenedAt` and `snippetBody`.
      Verified on device: a snippet created on the Mac reached the iPhone and
      iPad, and Get Info showed a correct Last Opened date (2026-08-28).
- [x] Release configuration installs cleanly to Mac, iPhone, and iPad via
      `CONFIGURATION=Release scripts/install-all-devices.sh` (2026-08-28).

- [x] Give the Mac a real install step: `scripts/install-mac.sh` installs to
      `/Applications/Tucked.app` instead of launching the build product in
      place, so the app survives a rebuild and shows in Spotlight (2026-07-25).

- [x] Restore native sidebar selection (keyboard nav + hover) by dropping custom pills (2026-08-12).
- [x] Decide accent default: moved from Graphite to Grape after device verification — gray-tinted buttons read too close to disabled (2026-07-19).
- [x] Custom sidebar selection styling (soft tinted pill + left accent bar) from the Tucked mockups (2026-07-19).
- [x] Reconsider the accent picker's Preview rows if pill styling never ships — resolved: pill styling shipped, so the picker preview now matches the real sidebar (2026-07-19).
