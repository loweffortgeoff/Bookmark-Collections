# Tucked TODO

Next holds the agreed work queue. Deferred holds work with a firm deadline. Backlog holds unscheduled work. Watch List items move only when their stated trigger occurs. Canceled items need a new product decision before they return.

Start here for current work; [decisions](DECISIONS.md), [change history](CHANGELOG.md), and the [device matrix](docs/verification/cloudkit-device-matrix.md) explain why, what landed, and what still needs verification. If TODO and changelog disagree, TODO is the queue authority.

## Next

- [x] Chapter 2 staged two-device purge/restore check (2026-11-10): Geoff reports pass on iPhone 17 and iPhone 17 Pro, Build 15 / `126b913`; restored link appears in `Dev Work` on both. [Evidence](docs/verification/cloudkit-device-matrix.md#chapter-2-purgerestore--2026-11-09).

**Release context (2026-11-07):** Geoff confirms 1.1.0 is live on iOS and macOS. The release/submission task is closed; the remaining menu bar checks below are still open.

- [ ] **Check the remaining Mac menu bar items** on a Release build: Links and Images items, Open Tucked with the window already open, Dock-click reopen, light mode, and window close keeps Tucked running. Geoff shipped 1.1.0 with these open (2026-11-06). Rows are in the [1.1.0 validation](docs/verification/2026-11-04-1.1.0-validation.md#a-local-checks-claude-no-upload).
- [ ] **Low priority, verify only: paywall under test launch arguments.** With `-ui-testing` and `-free-limit 0`, Unlock is disabled and the headline reads "Ten Bookmarks…". Check with the real StoreKit configuration before treating it as a bug.

- [ ] **Scope the first Siri and Shortcuts actions.** Choose from saving a link, finding bookmarks, opening a collection, and showing favorites or forgotten items; define indexing and link-sharing behavior. Geoff approved scoping on 2026-11-07, not an implementation bundle, version, or date; the starter ideas remain in Backlog.

- [ ] **Fix the 2026-11-09 adversarial review findings.** 24 findings, three chapters, one branch each: data loss, then previews/purge/purchase, then UI traps. Geoff approved subagent-driven execution on 2026-11-09. See the [plan](docs/superpowers/plans/2026-11-09-adversarial-review-fixes.md).
  - [x] Chapter 1, data loss: built and reviewed on `fix/review-data-loss` (2026-11-09). Mac unit suite passed 213 tests (13 skipped); Mac UI suite passed 17 tests (1 skipped), both with zero failures on Mac mini, macOS 27.2, Xcode 27.2. Merged locally to `main` at `411b8e8` with Geoff’s authorization on 2026-11-09.
  - [ ] Chapter 2, previews, purge, purchase: implemented on `fix/review-enrichment-purchase`; full Mac/iPhone unit and UI suites pass. Final review passed; failure, no-product paywall, and live-preview visuals passed. Awaiting merge authorization. See [verification](docs/verification/2026-11-09-review-chapter2.md).
    - [x] Task 2.1 (2026-11-09) implementation and review correction: one pending record per task, separate failed retries, and stale-result/deletion guards. Focused iPhone verification is in the task report; live preview confirmation and full suites pass; the final URL guard passes 30 metadata tests on both platforms.
    - [x] Task 2.2 (2026-11-09): activation purges expired deletions after reconciliation; the F17 newer-date import safeguard was brought forward into Chapter 2. All 58 focused import/purge tests and both simulator builds pass; the [two-device purge/restore check](docs/verification/cloudkit-device-matrix.md#chapter-2-purgerestore--2026-11-09) passed per Geoff on 2026-11-10.
    - [x] Task 2.3 (2026-11-09): the paywall retries missing products and shows only a StoreKit price. All 28 focused audit tests pass with zero skips; ordinary UI-test isolation is preserved. No-product layout and full suites pass; product loading has local audit coverage.
    - [x] Task 2.4 (2026-11-09): show library-open recovery text and Support without a fallback store. All 13 container tests, both simulator schemes, and the native Mac build pass. Failure/success visuals, full suites, and final review pass.
  - [ ] Chapter 3, UI traps.
  - [ ] Chapter 4, remaining F17 decision: define same-ID link-to-non-link collision behavior. The newer-date safeguard is complete in Chapter 2; no kind policy changed.

Clipboard capture has no demonstrated gap.

## Done — v1.1.0 (merged to `main` 2026-11-06)

Older completed work is under [Done](#done) at the end of this file.

- [x] **Release 1.1.0 (15).** Uploaded for iOS and macOS on 2026-11-06; Geoff confirms both versions are live on 2026-11-07. This closes the earlier processing, copy, and submission follow-up; no App Store Connect checks were repeated in this reconciliation. The remaining Mac menu bar checks stay in Next.

- [x] Reconcile current `main` into `dev/visual-polish`, preserving both iOS hotfixes and resolving the committed TODO conflict markers (2026-11-03). Signed iOS build and Mac/iPhone unit suites pass. UI failures were resolved during completed polish acceptance below.
- [x] Finish polish acceptance (2026-11-03). Geoff confirms Step 2 testing and verification complete. Share diagnosis is complete below. Step 4 highlighted-text capture is closed after Geoff confirmed iOS and Mac sharing on 2026-11-03. Step 5, the Mac menu bar helper, is built and verified locally on 2026-11-04.
- [x] Check Mac light/dark grid, selection, preview Info, editors, Settings, and paywall. Check iPhone standard/maximum text in both modes. Fix selection overflow, Collections wrapping, and Mac Info margins (2026-11-03).
- [x] Fix large-text sidebar word breaks (2026-11-03). Icons and counts stack above full-width titles with reduced row insets. Built-in labels stay whole in the 260-point simulator reproduction. Physical iPad retest accepted by Geoff on 2026-11-03.
- [x] Finish physical iPad mini polish acceptance (2026-11-03). Geoff confirms the remaining Step 2 checks complete on iPad mini. The iPad Pro resize symptom is on the Watch List. Evidence and report limits are in [Tucked Testing](/Users/geoffreysilva/Documents/Dev%20Workstation/The%20Notebook/Tucked%20Testing.md).
- [x] Resolve the Mac paywall launch and iPhone Edit/Get Info test failures (2026-11-03). Mac tests use a launch-argument separator. iPhone tests scroll the card fully into view. Full UI suites pass on Mac and iPhone 18 Pro with iOS 27.0, with no failures and one purchase-audit skip per platform.

Approved work queue (2026-10-21). Things: Tucked area, Bug Fixes and Feature Work projects. Original Things task numbers remain unchanged. Task 2 is done and task 3 was dropped.

- [x] **1. Diagnose the iOS Share storage failure** (2026-11-03). Geoff confirms sharing works on the current polish build. The former free-limit UI likely explains the Save/Retry symptom; original device logs are absent. All 48 targeted Share and limit tests pass on iPhone 18 Pro with iOS 27.0. No storage or entitlement change is needed.
  The November 2 fix `811c1c6` explains the free limit and hides ineffective Save/Retry controls. The older "could not open its shared library" report is a separate storage path and cannot be a limit block. Reopen for a fresh failure with its exact message and `ShareStorage`/`ShareSave` logs. Highlighted-text capture remains separate below.

1.1.0 includes card shadows, sidebar changes, the 2026-10-29 leftovers (`bee97be` and later), highlighted-text capture, and the Mac menu bar helper. See [change history](CHANGELOG.md#110--2026-11-06-ios-and-macos-build-15) and the [testing note](/Users/geoffreysilva/Documents/Dev%20Workstation/The%20Notebook/Tucked%20Testing.md).

- [x] **4. Save highlighted text as a snippet** (2026-11-03). Closed after Geoff confirmed iOS and Mac text sharing. Simulator capture and relaunch persistence also pass on iPhone 18 Pro with iOS 27.0. Source remains empty when the host does not supply one.
  Geoff confirms iOS and native Mac capture on 2026-11-03. iPad and source-bearing host combinations passed in the integrated 1.1.0 checks on build 14. The Mac initially invoked an old installed extension; current Release is now installed in `~/Applications/Tucked.app` and selected by PlugInKit. Check selected prose with and without an accompanying source URL. Clipboard capture has no demonstrated gap and is not added here.
- [x] **5. Fix Larger Text layout problems** (Things: Bug Fixes). Check the grid, cards, sidebar, and editor sheets at the largest accessibility text sizes on iPhone and iPad. Fix broken layouts, then reassess the Mac claim.
  Closed with Step 2 acceptance per Geoff on 2026-11-03. The 1.0 Larger Text claim covers iPhone and iPad only.
  2026-10-24: iPhone grid, link editor, snippet editor, and Settings pass at accessibility XXXL in light and dark (simulator). iPad and Mac host checks from the Oct-24 package were retired with that matrix (2026-10-31); they were not marked Passed. Layout acceptance criteria remain in the [spec](docs/superpowers/specs/2026-10-23-remaining-bug-fixes-design.md#b3-accessible-layouts-and-mac-failure-recovery).
  2026-10-29: a visual review on iPhone 18 Pro Max and iPad Pro 13" M5 (iOS 27.0) found layout leftovers. Screenshots are in `~/Documents/Dev Workstation/Visual Verification/Tucked/2026-10-29-1.1.0-review/`. Fixed in `e7f6eec`: cards no longer reserve a second title line at accessibility sizes, the collection picker is shared across the editors, and the snippet source field keeps its size. See [change history](CHANGELOG.md#changed--2026-10-29). The search placeholder and toolbar Cancel/Save do not scale by design ([decision](DECISIONS.md#2026-10-29-system-bars-keep-system-sizing-at-accessibility-text-sizes)).

**1.1.0 visual polish leftovers (2026-10-29 review):**

- [x] **Show the preview image in Get Info.** The Get Info sheet shows the URL, title, and metadata, but not the bookmark's preview image. Done 2026-10-29 in `3b31022`: the cached card thumbnail heads the sheet; snippets and links without a preview skip it.
- [x] **Decide card footer spacing (needs Geoff).** One-line titles leave a blank band above the domain and date, because `lineLimit(2, reservesSpace: true)` keeps grid rows even. Choose: even rows, or tight footers. Decided 2026-10-29: keep even rows ([decision](DECISIONS.md#2026-10-29-card-footers-keep-even-rows)); no code change.
- [x] **Move "Select" into the toolbar.** On every list, "Select" sits alone on its own row under the large title. Consider moving it into the toolbar. Done 2026-10-29 in `ca39de2`: Select/Done is in the library toolbar next to Add.
- [x] **Focus the Add Link URL field and use a URL keyboard.** The field is not focused when the sheet opens, and it shows the default keyboard. Done 2026-10-29 in `ca39de2`: focused on open, URL keyboard, no autocapitalization or autocorrection, Return saves.
- [x] **Give the selection action bar a background.** In Select mode the Favorite, Unfavorite, Move, Share, and Delete bar floats over the last card and the search field with no background. Seen 2026-10-29; predates moving Select. Done 2026-10-29 in `b663635`: floating material capsule; the last row scrolls clear of it.
- Low-priority paywall check under test launch arguments moved to Next.
- Settings shows "iCloud temporarily unavailable" under the in-memory test store. This is expected; no action.
- iPad captures show the real status-bar clock. This is a simulator capture setting, not an app bug; no action.

- [x] **6. Add the Mac menu bar helper** (done 2026-11-04; Links/Images items, light mode, and Release-build window checks remain in Next) (Things: Feature Work). After highlighted-text capture is settled, add Search, Links, Images, Snippets, Open Tucked, Settings, and Quit. Use the Stash menu as the reference; no tags.
  Add clipboard snippet capture and its keyboard shortcut only if Share capture leaves a real gap. This replaces the deferred Glaze-style quick-capture panel.

- [x] **Validate the shared 1.1.0** (Step 6, 2026-11-04 to 2026-11-06). TestFlight 1.1.0 (14) passed Mac purchase and restore, cross-platform access, both hotfix behaviors on Mac, Production sync, and iPad and source-bearing highlighted text. The last row closed on 2026-11-06 (`b4075c2`). Evidence: [1.1.0 validation](docs/verification/2026-11-04-1.1.0-validation.md). Menu bar checks remain in Next.

## Watch List

- [ ] **Repeat iPad Pro resize comparison after the next iPadOS beta update.** On iPad Pro 11-inch M5 with 27.3 Developer Beta, Files and Settings show similar movement to Tucked 1.1.0 (14). Geoff agrees to classify this as suspected iPadOS behavior and leave app code unchanged (2026-11-04). Record the new OS build and compare the same window drags. See [current evidence](docs/verification/2026-11-04-1.1.0-validation.md#ipad-pro-resize-reopened-2026-11-04).

- [ ] **Decide the permanent fix for identical clone pairs (review finding F1).** Importing one JSON backup on two devices before sync finishes makes two records with the same `id` and `createdAt`. The Chapter 1 fix stops Tucked from deleting them, but both copies stay visible until the user deletes one. A clean merge needs a new synced field and a Production CloudKit deploy. Geoff accepted the interim fix on 2026-11-09 on one condition: if no permanent fix follows, record that as a decision in DECISIONS.md and say it in the release notes. Trigger: the release that ships Chapter 1, or the first field report of duplicate pairs. See [Chapter 4, item 1](docs/superpowers/plans/2026-11-09-adversarial-review-fixes.md#chapter-4--decisions-for-geoff-no-code-until-chosen).

## Backlog

The deferred Photos picker and drag-and-drop items below are alternate in-app import paths, not missing Share Sheet support; macOS and iOS Share surfaces already capture images.

- Watch for the same stale-cell-geometry pattern (iPadOS 26 continuous window resize not re-proposing width to already-materialized cells) if other adaptive/resizable grid or list layouts are added later.
- Photos-picker in-app image import.
- Drag & drop image import onto the library grid (Mac/iPad).
- `pageDescription` field + og:description fetch for the info panel.
- Image bookmarks are excluded from JSON/HTML export; design image-capable backup.
- Encode shared photos as JPEG/HEIC instead of PNG (CloudKit payload size).
- Clipboard snippet capture, only if Share capture leaves a real gap. Shared text and the Mac menu bar shipped in 1.1.0.
- Untuck hub sheet (approach B) on top of `UntuckRules`.
- Configurable Forgotten threshold / Settings control.
- “Not opened in 30 days” re-entry (opened once, then stale again).
- Sort by last opened.
- First Siri and Shortcuts actions. Tucked has none today. Starter set: save a link to a collection, find bookmarks, open a collection, and show favorites or forgotten items. Add bookmarks to the Spotlight index, and let them pass to other apps as links. Write full descriptions from the start so the actions are ready for Apple's Siri AI preview. This is the Shortcuts idea from Tucked Testing (see v1.1.0 above). Rough size: 2–3 days. See the [Siri AI Prep Plan](https://claude.ai/artifact/VJDSbHGzy9tipzzCknTwxC) (2026-11-03).

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

- [x] Implement and submit iOS 1.0.2 (13). Settings Unlock/Restore, Share limit messaging, and About links include the 1.0.1 cap hotfix. iPhone checks passed on November 2. App Review accepted November 3, eligible for distribution (auto-release; public availability may lag up to 24h; submission `f6471180-6877-42a4-b797-975e02b8c0b9`); Mac remains at 1.0 until the shared 1.1.0 update.

- [x] **Device-test the approved paywall and JSON fixes.** Marked complete on `main` before reconciliation. Keep the [JSON fixtures](docs/verification/fixtures/2026-10-23-testflight/README.md) as historical instructions. The integrated 1.1.0 build has separate acceptance.

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
