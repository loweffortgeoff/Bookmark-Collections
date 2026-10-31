# Tucked TODO

Next holds the agreed work queue. Deferred holds work with a firm deadline. Backlog holds unscheduled work. Watch List items move only when their stated trigger occurs. Canceled items need a new product decision before they return.

Start here for current work; [decisions](DECISIONS.md), [change history](CHANGELOG.md), and the [device matrix](docs/verification/cloudkit-device-matrix.md) explain why, what landed, and what still needs verification. If TODO and changelog disagree, TODO is the queue authority.

## Next

**Release context (2026-10-31):** Build 11: iOS is App Store live; macOS is Waiting for Review. The Oct-24 remaining-bug-package / TestFlight 1.0 (10) device checklist is retired (2026-10-31); Pending rows were not marked Passed. Do not infer native macOS 1.0 approval from TestFlight or a version number. Geoff intends to get right on the [v1.1.0 follow-up](#v110) after native macOS 1.0 approval. Visual polish continues on this branch; Share diagnosis remains in the current queue.

- [ ] **Device-test the approved paywall and JSON fixes.** Local implementation, all 169 checks per platform, signed Release builds, and independent review pass. Still needed independently of the retired Oct-24 matrix: the [JSON pack](docs/verification/fixtures/2026-10-23-testflight/README.md), current-build purchase/restore and cross-device access, and fresh-account Production sync. See [audit and follow-up](docs/verification/2026-10-23-branch-paywall-audit.md).

Approved work queue (2026-10-21). Things: Tucked area, Bug Fixes and Feature Work projects. Tasks have no dates. Follow the numbered order across both projects.

- [ ] **1. Diagnose the iOS Share storage failure** (Things: Bug Fixes). Reproduce the failure, read `ShareStorage` logs, identify the cause, then retest links and images after a fix.

  2026-10-23 audit: live Safari link and Photos image sharing pass in the normal iPhone 18 Pro simulator store and survive relaunch. The physical-device failure and CloudKit sync remain unverified.

  The Oct-24 matrix B2 row was retired with that package (2026-10-31); it was not marked Passed. This diagnose item stays open on the 2026-10-23 evidence, not as a leftover matrix gate.

  Prior investigation: reproduce the iOS Share-extension storage failure and inspect its new
  `ShareStorage` log before changing storage or entitlement configuration.
  The failure message is "Tucked could not open its shared library," and it
  blocks every share, including links and images. Highlighted-text share is
  the separate v1.1.0 item below unless that storage message is what appears.
  The 2026-10-23 macOS share fix did not resolve this iOS failure. The `ShareStorage`
  log now records the error domain and code down the underlying-error chain, which
  should make the cause diagnosable.

### v1.1.0

Geoff intends to get right on this follow-up after native macOS 1.0 approval. Visual polish has already started; Share diagnosis remains in [Next](#next). None of this blocks 1.0. The approved numbered order starts with Share storage; task 2 is done and task 3 was dropped. The following items keep their existing order.

**Already started:** `dev/visual-polish` contains card shadows, sidebar changes, and the 2026-10-29 leftovers (`bee97be` and later), not yet merged to `main`. Finish and verify Mac selection, iPad live resize, and light/dark appearance; Larger Text layout leftovers fit this branch. Later 2026-10-29 polish (Select in the toolbar, Add Link focus, selection bar background, Get Info preview, card footer decision) is in the leftovers list below. See [change history](CHANGELOG.md#changed--2026-10-26) and the [testing note](/Users/geoffreysilva/Documents/Dev%20Workstation/The%20Notebook/Tucked%20Testing.md). This does not include Share storage, highlighted-text capture, the menu bar helper, or Shortcuts.

- [ ] **4. Save highlighted text as a snippet** (Things: Feature Work). After Share storage works, test prose with and without a page URL on Mac and iOS. Save the selection as snippet text and keep the page URL as its optional source.
  The current loader rejects prose without a URL or prefers a supplied page URL and drops the selection. Confirm the actual result first. The storage error in Next is a separate failure. Existing snippet behavior and its historical design are in the [snippet decision](DECISIONS.md#2026-08-28-snippets-reuse-the-bookmark-model-rather-than-getting-their-own) and [design](docs/superpowers/archive/2026-08-28-glaze-parity-snippets-design.md).
  Found 2026-10-23: a plain-text selection in Safari reaches the Mac share extension with no attachments (probably the text sits in the extension item's text content, not an attachment). It is a deterministic Mac repro for the share failure card and needs no paywall state.
- [ ] **5. Fix Larger Text layout problems** (Things: Bug Fixes). Check the grid, cards, sidebar, and editor sheets at the largest accessibility text sizes on iPhone and iPad. Fix broken layouts, then reassess the Mac claim.
  Reported 2026-10-14. The 1.0 Larger Text claim covers iPhone and iPad only.
  2026-10-24: iPhone grid, link editor, snippet editor, and Settings pass at accessibility XXXL in light and dark (simulator). iPad and Mac host checks from the Oct-24 package were retired with that matrix (2026-10-31); they were not marked Passed. Layout acceptance criteria remain in the [spec](docs/superpowers/specs/2026-10-23-remaining-bug-fixes-design.md#b3-accessible-layouts-and-mac-failure-recovery).
  2026-10-29: a visual review on iPhone 18 Pro Max and iPad Pro 13" M5 (iOS 27.0) found layout leftovers. Screenshots are in `~/Documents/Dev Workstation/Visual Verification/Tucked/2026-10-29-1.1.0-review/`. Fixed in `e7f6eec`: cards no longer reserve a second title line at accessibility sizes, the collection picker is shared across the editors, and the snippet source field keeps its size. See [change history](CHANGELOG.md#changed--2026-10-29). The search placeholder and toolbar Cancel/Save do not scale by design ([decision](DECISIONS.md#2026-10-29-system-bars-keep-system-sizing-at-accessibility-text-sizes)).

**1.1.0 visual polish leftovers (2026-10-29 review):**

- [x] **Show the preview image in Get Info.** The Get Info sheet shows the URL, title, and metadata, but not the bookmark's preview image. Done 2026-10-29 in `3b31022`: the cached card thumbnail heads the sheet; snippets and links without a preview skip it.
- [x] **Decide card footer spacing (needs Geoff).** One-line titles leave a blank band above the domain and date, because `lineLimit(2, reservesSpace: true)` keeps grid rows even. Choose: even rows, or tight footers. Decided 2026-10-29: keep even rows ([decision](DECISIONS.md#2026-10-29-card-footers-keep-even-rows)); no code change.
- [x] **Move "Select" into the toolbar.** On every list, "Select" sits alone on its own row under the large title. Consider moving it into the toolbar. Done 2026-10-29 in `ca39de2`: Select/Done is in the library toolbar next to Add.
- [x] **Focus the Add Link URL field and use a URL keyboard.** The field is not focused when the sheet opens, and it shows the default keyboard. Done 2026-10-29 in `ca39de2`: focused on open, URL keyboard, no autocapitalization or autocorrection, Return saves.
- [x] **Give the selection action bar a background.** In Select mode the Favorite, Unfavorite, Move, Share, and Delete bar floats over the last card and the search field with no background. Seen 2026-10-29; predates moving Select. Done 2026-10-29 in `b663635`: floating material capsule; the last row scrolls clear of it.
- [ ] **Low priority, verify only: paywall under test launch arguments.** With `-ui-testing` and `-free-limit 0`, Unlock is disabled and the headline reads "Ten Bookmarks…". Check with the real StoreKit configuration before treating it as a bug.
- Settings shows "iCloud temporarily unavailable" under the in-memory test store. This is expected; no action.
- iPad captures show the real status-bar clock. This is a simulator capture setting, not an app bug; no action.

- [ ] **6. Add the Mac menu bar helper** (Things: Feature Work). After highlighted-text capture is settled, add Search, Links, Images, Snippets, Open Tucked, Settings, and Quit. Use the Stash menu as the reference; no tags.
  Add clipboard snippet capture and its keyboard shortcut only if Share capture leaves a real gap. This replaces the deferred Glaze-style quick-capture panel.

Shortcuts remains an idea from Tucked Testing. Clipboard capture is the remaining scope question; settle it from task 4 before task 6.

## Backlog

The deferred Photos picker and drag-and-drop items below are alternate in-app import paths, not missing Share Sheet support; macOS and iOS Share surfaces already capture images.

- Verify on a physical iPad that window resize no longer shudders or shows the 2026-07-19 "window shade" clipping now that the grid uses explicit widths (2026-10-29).
- Watch for the same stale-cell-geometry pattern (iPadOS 26 continuous window resize not re-proposing width to already-materialized cells) if other adaptive/resizable grid or list layouts are added later.
- Photos-picker in-app image import.
- Drag & drop image import onto the library grid (Mac/iPad).
- `pageDescription` field + og:description fetch for the info panel.
- Image bookmarks are excluded from JSON/HTML export; design image-capable backup.
- Encode shared photos as JPEG/HEIC instead of PNG (CloudKit payload size).
- Sharing plain non-URL text, clipboard snippet capture, and a Mac menu bar extra are in v1.1.0 above.
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

Historical v1 exclusions, not firm deadlines or committed work:

These items were explicitly excluded from v1 and are not release blockers or committed roadmap work:

- Tags and multi-label organization.
- Offline webpage archives, reader mode, and standalone image storage.
- Shared or collaborative collections.
- Browser extensions.
- Custom accounts or non-CloudKit sync servers.
- Analytics or telemetry SDKs.

## Done

_Earlier v1 work landed before TODO.md tracked completions with dates._

- [x] Oct-24 remaining-bug-package device acceptance retired (2026-10-31). Geoffrey retired the checklist; Pending rows were not marked Passed. Visual/performance work continued on `dev/visual-polish` (not merged). iOS Build 11 is App Store live; macOS Build 11 is Waiting for Review.

- [x] **Merge Settings → About links** ✅ 2026-10-25 (`b33aecd` on `main`). Privacy Policy, Support, and the Low Effort Apps website. Marketing version stays 1.0 so a rejection can ship them in a new 1.0 build. Active 1.1 visual work is on `dev/visual-polish`.

- [x] **Finish verifying the Mac share failure card** (unnumbered; follow-up to the 2026-10-23 Mac share fix). On a Mac, check four things: the free-limit message text in the share sheet, light mode, the largest accessibility text size (the fixed 360 x 200 frame could clip the buttons), and the storage-failure screen. The window background is unverified: if the card looks doubled, remove the one `.background` line in `ShareViewController.host`.

  2026-10-23 audit: live Safari at the free limit shows readable message text, Cancel, and Retry in light and dark mode. Retry remains blocked; Cancel dismisses. Largest text and a live storage-failure screen remain open.

  2026-10-24: the fixed 360 x 200 frame is gone; the card now scrolls. The free-limit card offers Open Tucked and Cancel instead of Retry. Typed recovery tests pass. Oct-24 leftover real-host checks are retired (2026-10-31); they were not marked Passed.

  Previously seen working: a plain-text share shows "Share a web link or an image." in dark mode with the window background. To repro the limit, edit the App Group prefs plist (`~/Library/Group Containers/group.com.loweffortapps.BookmarkCollections/Library/Preferences/group.com.loweffortapps.BookmarkCollections.plist`, key `tuckedProUnlocked`) with `plutil -replace tuckedProUnlocked -bool NO`, then `killall cfprefsd`. `defaults write` edits the wrong file because the CLI is not sandboxed. Do not open Tucked before sharing; launch rechecks StoreKit and can reset the flag. Read logs with `/usr/bin/log show --last 5m --info --predicate 'subsystem == "com.loweffortapps.BookmarkCollections"'` (full path; plain `log` is a zsh built-in). Categories: `ShareSave`, `ShareStorage`.

  > **Branch state:** `fix/mac-save-to-tucked` was merged before `158fbb3`. Oct-24 leftover host checks are retired, not still queued.

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

- [x] Remaining bug block implemented, verified locally, and merged to `main`. [Spec](docs/superpowers/specs/2026-10-23-remaining-bug-fixes-design.md), [plan](docs/superpowers/plans/2026-10-23-remaining-bug-fixes.md) (2026-10-24).
- [x] Mac menu Open/Share for links, images, and snippets, plus Cancel and stale selection, pass the native Mac UI test. Commands now target the last item acted on, not hover (2026-10-24).
- [x] Mac Share free-limit Open Tucked/Cancel and failed-open recovery pass typed recovery tests. Oct-24 leftover real-host checks are retired (2026-10-31); they were not marked Passed.

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
