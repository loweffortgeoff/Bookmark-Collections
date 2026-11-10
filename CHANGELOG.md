# Changelog

All notable project changes are recorded here. For the current queue, see [TODO](TODO.md). Dated entries retain their historical context.

## In Progress

### Review fixes, Chapter 3: UI traps (merged to `main` locally 2026-11-10, not pushed)

From the 2026-11-09 adversarial review ([plan](docs/superpowers/plans/2026-11-09-adversarial-review-fixes.md), findings F11 to F14, F16, F18 to F20).

- Fixed: a long-press on a link with an empty or unreadable address no longer crashes.
- Fixed: selection mode ends when you change to another view. Done shows whenever selection is on. Bulk Share is disabled when the selection has no web address.
- Fixed: Add Link and text import accept `example.com` and `www.example.com/page`. Tucked adds `https://`. Text that is not a web address, such as `v1.2` or an email address, stays an invalid line.
- Fixed: at the free limit, Save in Add Link or the snippet editor opens the paywall over the editor. The typed text is still there when the paywall closes.
- Fixed: with a sheet open on the Mac, Cmd+Delete in a text field no longer moves the item to Recently Deleted. Add Link, New Snippet, New Collection, Add Images, and Surprise Me do nothing while a sheet is open. A menu bar choice made while an editor is open is ignored.
- Changed: a text or image import that meets the free limit keeps the items it saved and shows a summary with "Stopped at the free limit" and an Unlock button. Before, it showed the paywall with no summary.
- Fixed: the image viewer decodes the image once, not on every pinch frame.
- Verification (Mac mini, macOS 27.2, Xcode 27.2, `db57eeb`): Mac unit/UI suites pass 261/19 cases; iPhone 18 Pro iOS 27.0 passes 257/19. Expected skips are 15 unit and one UI per platform; zero failures. Both simulator schemes build. No visual check was done.

- Chapter 2 merged to `main` locally at `bffbf0b` (2026-11-10), not pushed. Merge gate at that commit: Mac unit/UI 254/17, iPhone unit/UI 250/18, zero failures.

- Verification procedure corrected (2026-11-10): sync a recent deletion first, then age only the offline device’s copy. The original two-device purge attempt stopped during setup; Geoff reports the revised check passed on both physical iPhones at `126b913`, with the restored link in `Dev Work` (03:50 am).

- Chapter 2 integrated checks (2026-11-09, Mac mini, macOS/Xcode 27.2): Mac unit/UI suites pass 253/17 cases; iPhone 18 Pro iOS 27.0 passes 249/18. Expected skips are 15 unit and one UI per platform; zero failures. Failure/success, no-product paywall, and live-preview visuals pass; the final URL guard passes 30 metadata tests per platform. [Evidence](docs/verification/2026-11-09-review-chapter2.md).

### Review fixes, Chapter 2: Task 2.4 (2026-11-09)

- Fixed: a library-open failure shows recovery text and a Support link instead of crashing. Log safe error codes and private details; do not create a fallback store.
- Verification: all 13 container tests pass on iPhone 18 Pro with iOS 27.0; both simulator schemes and the native Mac app build. Failure-screen and success-control visuals pass; integrated suites pass.

### Review fixes, Chapter 2: Task 2.3 (2026-11-09)

- Fixed: opening the paywall retries a missing product without overlapping an active load. Show the StoreKit price when available, progress while loading, and no invented price.
- Verification: all 15 Storefront and 13 paywall-gate audit tests pass with local StoreKit on iPhone 18 Pro, iOS 27.0, with zero skips. Both simulator schemes build; ordinary UI tests remain isolated. No-product layout was inspected; integrated suites pass.

### Review fixes, Chapter 2: Task 2.1 (2026-11-09)

- Fixed: new links start metadata enrichment while the library is open. Each result saves separately; cancelled fetches stay pending, and deleted links are skipped before and after fetching.
- Final guard: changing a link’s URL during a fetch discards the old result and restarts the pending request for the new URL.
- Review correction: each library task enriches its oldest pending record by persistent identity. Activation retries only due failures; late results are discarded after another refresh or a detected row deletion.
- Verification: 29 metadata tests pass on iPhone 18 Pro with iOS 27.0; both simulator schemes build. Live Apple/Swift/Python previews pass without backgrounding; integrated suites pass.

### Review fixes, Chapter 2: Task 2.2 (2026-11-09)

- Changed: activation now purges items deleted more than 30 days ago, after duplicate cleanup. Expired links stay if an active link has the same normalized URL; images and snippets purge normally.
- Fixed: brought the F17 date safeguard forward into Chapter 2. JSON import preserves newer same-ID links, snippets, and collections; capacity checks use the same date rule, including repeated records within a backup.
- Verification: all 58 focused import/purge tests pass on iPhone 18 Pro with iOS 27.0; both simulator schemes build. Integrated suites pass; the two-device purge/restore check remains pending; the F17 kind-collision decision stays in Chapter 4.

### Review fixes, Chapter 1: data loss (merged to `main` 2026-11-09)

From the 2026-11-09 adversarial review ([plan](docs/superpowers/plans/2026-11-09-adversarial-review-fixes.md), findings F1 to F5).

- Fixed: the same JSON backup imported on two devices no longer makes each device delete the other's copy of every link. Identical copies now stay; duplicate cleanup leaves them alone.
- Fixed: JSON import no longer crashes when the library holds two records with the same id.
- Fixed: duplicate cleanup no longer keeps a deleted record over an active copy. The earliest record stays and becomes active again.
- Fixed: fetching a preview no longer replaces a title. Restored and edited titles stay; Refresh Preview does not rename.
- Fixed: text import and URL drop no longer clear the collection and Favorite of a link that is already saved.
- Changed: at the free limit, a JSON import of an active copy of a deleted link now stops at the limit. In 1.1.0 it reported success and left the link deleted.
- Known limit: identical copies from a double import stay visible until the user deletes one ([decision](DECISIONS.md#2026-11-09-keep-identical-copies-from-a-double-import)).

## Release history

> **Platform note:** 1.0.1 and 1.0.2 shipped on iOS only. The approved Mac 1.0 (2026-11-02) carries the 1.0 source plus the Mac App Review fix (window reopen, unused entitlements; `4931b3a`). 1.1.0 is the first shared iOS and macOS update, so it brings the 1.0.1 and 1.0.2 changes to Mac.

### 1.1.0 — 2026-11-06 (iOS and macOS; build 15)

Merged `dev/visual-polish` to `main` at `b4075c2` on 2026-11-06. Build 15 has the same app code as TestFlight build 14, which carries the device validation; only UI-test files changed after build 14. The Mac menu bar items for Links, Images, Open Tucked with the window open, Dock-click reopen, light mode, and window close in a Release build were not checked; Geoff chose to ship with them open.

- Delivery (2026-11-06, MacBook Pro, macOS 27.2, Xcode 27.2): archived `Tucked Release` for iOS and macOS; app and extension read 1.1.0 (15). Both uploads succeeded through Xcode distribution. ASC processing, export compliance, and the copy transfer were not checked: the ASC API rejected this Mac's credentials. Not attached to a version or submitted.

#### Investigated 2026-11-04 (iPad Pro resize)

- The iPad Pro 11-inch M5 comparison recording shows similar resize movement in Files, Settings, and Tucked on iPadOS 27.3 Developer Beta. Geoff agrees to track suspected iPadOS behavior and recheck after the next beta. App code is unchanged. The earlier acceptance covered iPad mini only. See [current evidence](docs/verification/2026-11-04-1.1.0-validation.md#ipad-pro-resize-reopened-2026-11-04).

#### Fixed 2026-11-04 (Mac UI test harness)

- Mac UI tests no longer launch into a menu bar with no window. Cause: saved window state is shared by every Tucked copy with the same bundle ID, and a copy that closed its window left state with no window. Also, a bare launch-argument value without a leading `--` suppresses the initial window. Every Mac UI launch now starts with `--` and adds `-ApplePersistenceIgnoreState YES` (`TuckedLaunch.swift`). App code is unchanged.
- Sidebar tests scroll the sidebar before they click a row that is clipped at the bottom (likely cause of one rare Recently Deleted flake; not proven).
- Verification (Mac mini, macOS 27.2, Xcode 27.2): with windowless state written on purpose before each run, two consecutive full Mac UI runs pass, 17 cases each with one expected purchase-audit skip. Without the fix, the same state fails `testAppLaunches` and the snippets test with the same errors as the 06:12 failing run. iOS UI test target builds. Share extension not rebuilt; app code is unchanged. Details in the [1.1.0 validation note](docs/verification/2026-11-04-1.1.0-validation.md#mac-ui-suite-failure-2026-11-04-root-cause-found-harness-fixed).

#### Added 2026-11-04

- Mac menu bar helper: Search, Links, Images, Snippets, Open Tucked, Settings, and Quit. Each item opens or raises the library window on that view; Search focuses the search field and Settings opens the Settings sheet. No clipboard capture added.
- Closing the Mac library window now leaves Tucked running in the menu bar instead of quitting. The Mac library is a single-instance window so the menu can reopen it.
- Verification: iOS app, share extension, and macOS builds pass. Mac unit suite runs 196 cases (13 expected skips) and Mac UI suite 17 cases (1 expected skip), zero failures. Live menu checks (close, reopen on Snippets, Settings, Search, Quit) are in the Visual Verification folder `Tucked/2026-11-04-menubar-helper`. Links, Images, light mode, and a signed Release build are unchecked.

#### Added 2026-11-03

- Share selected text into a snippet on iPhone, iPad, and Mac. Keep paragraphs, embedded links, and a separately supplied source URL. iPhone and iPad show the text before saving; Mac retains Quick Save.
- Ordinary Safari page shares remain links. Image captions do not replace images. Snippets use the existing local save, free limit, Collection, and Favorite behavior without a schema change.
- Verification on macOS 27.2 with Xcode 27.2: signed iOS Release build passes; Mac unit suite runs 196 cases and iPhone unit suite runs 192, each with 13 expected StoreKit audit skips and zero failures.
- Full UI suites pass on Mac and iPhone 18 Pro with iOS 27.0: 17 and 18 cases, each with one expected purchase-audit skip and zero failures. Final Mac and simulator builds pass.
- Live Safari selection capture, Cancel, Save, and relaunch persistence pass on iPhone 18 Pro with iOS 27.0. Geoff confirms iOS and native Mac text sharing; Step 4 is closed. iPad and source-bearing host combinations remain integrated 1.1.0 checks. Evidence is in Tucked Testing and `build/highlight-*`.

#### Mac Share installation corrected 2026-11-03

- Geoff confirms iOS snippet capture. Mac Safari invoked the old `/Applications/Tucked.app` extension while the new app ran from Xcode. Installed current Release in `~/Applications/Tucked.app`; signature and binary match pass, and PlugInKit selects that copy. Geoff confirms Mac text sharing works after the installation correction.

#### Share diagnosis closed 2026-11-03

- Geoff confirms sharing works on the current polish build. The old free-limit UI likely explains the Save/Retry symptom; original device logs are absent. No app-code or storage change is needed.
- All 48 targeted Share and limit tests pass on iPhone 18 Pro with iOS 27.0, using macOS 27.2 and Xcode 27.2. Highlighted-text capture is next.

#### Polish acceptance closed 2026-11-03

- Geoff confirms Step 2 testing and verification complete, including the physical iPad sidebar retest and remaining combinations. Share failure diagnosis is next; integrated 1.1.0 packaging checks remain separate.

#### Appearance checks 2026-11-03

- Accessibility-size sidebar rows place the icon and count above the title and reclaim horizontal row space. Built-in labels stay whole in the 260-point simulator reproduction. Geoff accepted the physical iPad retest on 2026-11-03.
- Sidebar verification passes on macOS 27.2 with Xcode 27.2 and iPhone 18 Pro with iOS 27.0. Mac and simulator builds pass. Three focused UI cases pass with zero failures.
- Maximum-text selection uses two action rows without widening the library. Collections stacks its add button when needed. The Add menu uses a compact folder label with the full accessibility name.
- Mac Get Info uses a native grouped form so previews and labels stay inside the sheet. Light and dark appearance checked on Mac and iPhone 18 Pro with iOS 27.0.
- Signed iOS Release build and full UI suites pass. Mac ran 17 cases and iPhone ran 18, each with one expected purchase-audit skip and zero failures.
- Physical iPad mini recordings on iPadOS 27.2 cover resize, rotation, light/dark sheets, URL and snippet keyboards, and large-text snippet editing. Geoff confirms the remaining Step 2 checks complete. Integrated-candidate purchase/restore checks remain in packaging.

#### Fixed 2026-11-03

- UI tests restore the Mac paywall window with a launch-argument separator. iPhone context-menu tests scroll the target card fully on screen before pressing. App behavior is unchanged.
- Full UI suites pass on macOS 27.2 with Xcode 27.2 and iPhone 18 Pro with iOS 27.0. Mac ran 17 cases and iPhone ran 18, each with one expected purchase-audit skip and no failures.

#### Reconciled 2026-11-03

- Merged current `main` into `dev/visual-polish`, retaining both iOS hotfixes. Signed iOS build and Mac/iPhone unit suites pass. Existing Mac paywall-launch and iPhone context-menu UI failures remain in 1.1.0 polish acceptance.

#### Fixed — 2026-10-29

- The library grid no longer rebuilds itself every 20pt during an iPad window resize. Fixed columns and an explicit card width resize cells in place, which should stop the resize shudder.
- Card previews decode off the main thread at card size and stay cached, so scrolling and resizing no longer decode full-size stored images on every render.
- The library list is filtered and sorted once per redraw instead of up to five times, and search trims its text once rather than once per bookmark. Surprise Me's enabled state stops at the first match instead of building the full candidate list.
- Link preview refresh on launch and return to the app saves once per batch instead of once per bookmark, so the library no longer redraws up to 20 times in a row. It also loads only unfinished bookmarks instead of the whole library.
- Sidebar counts come from one pass over the library instead of one pass per row.
- New link previews are stored as JPEG (quality 0.8) instead of PNG, which is usually several times smaller for photos. Previews with transparency stay PNG. Saved images are unchanged: they stay lossless PNG, since share and export hand them back as stored. Existing previews are not converted.

#### Changed — 2026-10-29

- Cards no longer reserve a second title line at accessibility text sizes (one-column grid), which removes the gap between title and subtitle.
- Add Link, Edit, Get Info, and the snippet editor share one collection picker. At accessibility sizes it stacks the label over a flush-leading menu instead of the system row's indented wrap.
- The snippet source field uses a short "Source link" placeholder at accessibility sizes, so it no longer shrinks.
- The dark-mode editor accessibility test now submits its search so the keyboard does not cover context-menu items. Both accessibility UI tests pass.
- Add Link focuses its address field when it opens and uses the URL keyboard, with autocapitalization and autocorrection off. Return saves when the field has text.
- Select/Done moves from its own row under the large title into the library toolbar, next to Add.
- The Select-mode action bar (Favorite, Unfavorite, Move, Share, Delete) now sits on a floating material capsule instead of directly over the cards.
- Get Info shows the bookmark's preview image at the top, using the same cached thumbnail as the card. Snippets and links without a preview skip it.
- Left as is: the "Search bookmarks" placeholder and toolbar Cancel/Save do not scale at accessibility sizes. See [the decision](DECISIONS.md#2026-10-29-system-bars-keep-system-sizing-at-accessibility-text-sizes).

#### Changed — 2026-10-26

- Added subtle card shadows and refined the native sidebar with accent-colored icons and section spacing.

### 1.0.2 — 2026-11-02 (iOS; build 13 approved by App Review on 2026-11-03)

- Settings has a "Tucked for Life" section while locked: **Unlock Tucked for Life** opens the paywall and **Restore Purchases** works without hitting the limit first. Unlocked users still see the badge.
- The Share sheet at the free limit explains it in plain text instead of a red error, and hides Save and Retry, which cannot succeed there. Mac keeps its Open Tucked and Cancel buttons.
- Settings → About links to the Privacy Policy, Support, and the Low Effort Apps website.
- Includes the 1.0.1 free-cap change. Device-checked on iPhone: Settings row, paywall, sandbox purchase, Restore, and a saved link after unlock.

### 1.0.1 — 2026-10-31 (iOS hotfix, build 12)

- The free ten-bookmark cap applies only after the App Store returns Tucked for Life. Until then the app and the Share extension save without a limit. The app records the answer in the app group, and the extension reads it from there. An empty catalog answer lifts the cap; a failed lookup (offline) keeps the last answer. Bookmarks saved past ten while the product was unavailable are kept. When the product loads, only new saves past ten reach the paywall, and existing items can still be edited and re-shared.
- Version 1.0.1 (12). The live iOS build 11 has the same source as build 10 (no Settings About links).

### 1.0 fixes before 1.0.1 (builds 10 and 11, iOS)

#### Fixed — 2026-10-24 (in TestFlight 1.0 (10); device acceptance pending)

- Re-sharing keeps saved titles, organization, and previews. Interactive Share loads existing choices; explicit None/off still applies. Suggested names no longer mark metadata complete.
- iOS Share offers Retry when it cannot read an already-saved link. Retry reads the saved values again before it saves, so the form's defaults never clear them.
- Accessibility text sizes use full-width cards. The link editor applies its minimum width only on Mac. Mac failure messages scroll; free-limit failures offer Open Tucked and Cancel.
- Mac menu Share uses the selected link, image, or snippet. Missing images show an image error; stale selection disables commands. Extension paywall values and test deployment floors are explicit.
- Mac Bookmark menu commands act on the item last clicked, focused, or used with Edit or Get Info. The card under the pointer no longer becomes the target.

#### Added — 2026-10-24

- TestFlight 1.0 (10) from `a17ab86` is available internally on iPhone and native Mac with the Release paywall enabled. Both builds are `VALID` and In Beta Testing in the internal group, with What to Test and export compliance saved. Not attached to an App Store version or submitted. See [the matrix](docs/verification/cloudkit-device-matrix.md#testflight-candidate--2026-10-24).

#### Changed — 2026-10-24

- UI-test launches without `-storekit-audit` no longer query StoreKit, so a Mac that owns Tucked cannot unlock the test library. The Mac StoreKit audit cannot run on a Mac whose Apple Account owns Tucked for Life.
- Added a [first-time tester checklist](docs/verification/2026-10-24-testflight-fresh-tester-checklist.md) for the next TestFlight build.

#### Fixed — 2026-10-23

- Verified lifetime purchases unlock the active Mac app before transaction completion. Ownership checks survive product-catalog failures; successful purchase, approval, and restore clear obsolete errors and close the paywall.
- JSON import checks reconciled capacity before changing data. Duplicate-only updates remain free, rejected imports preserve collections and pending edits, and sync duplicates cannot hide new growth past ten.

- Mac Share ▸ "Save to Tucked" no longer fails silently. The Mac share view was created with a zero-size frame, so nothing the extension showed was visible and Safari only dimmed. The view now has a 360 x 200 frame, and the failure card appears with its title, message, Cancel, and Retry.
- Mac share failure screens use a plain-stack `MacShareFailureView` that fits the fixed frame. The iOS `ShareStoreFailureView` is unchanged.
- The Mac Share controller applies one window background where it hosts SwiftUI content.

#### Added — 2026-10-23

- Draft spec and full-send plan scope the remaining bug block. No app changes or device-gate completion are claimed.
- TestFlight 1.0 (9) from `f34b8c6` is available internally on iPhone and native Mac with the Release paywall enabled. Five validated JSON fixtures cover capacity, duplicate updates, rejection without mutations, and unlocked expansion.
- Release audit adds gate, import, StoreKit, and UI regression coverage. Confirmed defects and submission gaps are recorded in [the branch audit](docs/verification/2026-10-23-branch-paywall-audit.md). The initial audit preceded the approved fixes above.
- Share diagnostics: a `ShareSave` log category. `ShareStorageDiagnostics.logSummary` logs the error domain and code down the underlying-error chain. The full error is logged as private. A notice records when the free-bookmark limit blocks a save. Item type identifiers are logged when a share holds nothing to save. A "Share view appeared" entry logs the view and window frames.
- Unit tests for the free-limit failure and `logSummary`.

#### Added — 2026-10-15

- Tucked for Life paywall: save 10 active bookmarks free, then unlock unlimited links, images, and snippets with a $4.99 lifetime non-consumable purchase (`com.loweffortapps.BookmarkCollections.tuckedforlife`). Existing bookmarks, export, and deletion remain free.
- Paywall lists an "independent developer" support row and a footnote that existing bookmarks stay put.
- `Tucked Beta` bypasses monetization for ordinary TestFlight builds. `Tucked Release` enables the paywall for release and sandbox-purchase testing.
- `Tucked.storekit` local configuration for purchase testing.
- Settings shows a "Tucked for Life" seal row at the top once the purchase is unlocked.

---

### 1.0 — 2026-10-14

#### Added

- Universal SwiftUI bookmark library for iPhone, iPad, and Mac.
- Local-first SwiftData storage with private CloudKit mirroring.
- Share Extension with immediate validated URL saving through the shared App Group.
- Visual preview cards, Favorites, single-membership Collections, search, sorting, drag-and-drop, context menus, and bulk actions.
- Recently Deleted with restore, confirmed permanent deletion, and 30-day purge behavior.
- Link metadata enrichment with durable URL fallback when metadata fails.
- UTF-8 text import, portable HTML export, and versioned JSON backup/restore.
- Settings with honest iCloud account availability and import/export summaries.
- Native macOS commands, keyboard focus behavior, semantic accessibility labels, and adaptive light/dark Dynamic Type layouts.
- Duplicate reconciliation for independently saved normalized URLs after CloudKit merges.
- New Tucked app icon: a curious star peeking from a pocket in the Dusk Candy palette.
- Get Info panel on the bookmark context menu (URL, title, collection, favorite, added/modified dates).
- Save images and screenshots via the Share Sheet; new Images and Links sidebar filters; full-screen image viewer.
- Sidebar shows item counts for All Items, Images, Links, Favorites, and each collection.
- Forgotten library destination: never-opened items older than 30 days.
- Surprise me toolbar action: opens a random item from the current visible set.
- Track `lastOpenedAt` when opening links or the image viewer; include it in JSON backups.
- Text snippets: a third bookmark kind holding a piece of text with an optional source link, its own Snippets sidebar destination, a text-excerpt card, and Copy Text. Search matches snippet bodies.
- JSON backup carries snippets under a top-level `snippets` key. A backup written before this change still restores.
- `File ▸ Add Images…` on macOS adds images from a file picker rather than only through the Share menu.

#### Changed — 2026-08-12

- Removed the in-app accent picker and custom sidebar pills. Tint and
  sidebar selection now follow the system (macOS system accent; iOS
  default blue).

#### Fixed — 2026-09-21

- Link previews recover after a temporary metadata failure. A failed fetch now
  retries after one hour instead of staying blank forever. New saves are always
  fetched before old failures. A metadata fetch that returns no image no longer
  erases a preview that is already stored.
- Fixed blank link previews and domain-only titles on Mac. The sandboxed Mac app
  had outgoing network access disabled, so it could not fetch any link metadata.
  The app target now enables outgoing network connections, matching the Share
  Extension.

#### Fixed — 2026-08-29

- Share-extension storage failures now show a clear recovery step and log the
  underlying local error instead of showing an unexplained Retry action.
- Fixed the macOS application menu name. It used `CFBundleName`, which still
  expanded to the internal `BookmarkCollections` target name despite the
  display name already being Tucked.
- Fixed the multi-select bottom bar's action labels wrapping into a
  letter-stack ("Fa/vo/rit/e") under space pressure — switched to icon-only
  buttons, spread full-width with `Spacer()`s, with the surrounding
  background removed (see DECISIONS.md, 2026-08-29).

#### Fixed — 2026-08-30

- Renamed the packaged app product to `Tucked.app` while keeping the internal
  target, bundle identifier, and Swift module names unchanged. macOS
  TestFlight installs now use Tucked in Applications and Launchpad instead of
  the internal `BookmarkCollections` name.

#### Fixed — 2026-07-25

- Fixed the Mac never actually installing. `scripts/install-all-devices.sh`
  built the Mac app and launched it in place out of `build/DerivedData`, so the
  only copy lived in a build directory that the next rebuild, macOS UI test run,
  or `scripts/reset-ui-tests.sh` deleted — the app stopped running with nothing
  left to relaunch, and Spotlight had no installed app to find. The Mac now
  installs to `/Applications/Tucked.app` via `scripts/install-mac.sh`, which the
  combined script calls. iPhone and iPad installs are unchanged.
- Installed the Mac app as `Tucked.app` rather than `BookmarkCollections.app`.
  Finder and Spotlight match applications on the bundle's file name, not
  `CFBundleDisplayName`, so searching "Tucked" previously found nothing.
- Scoped `scripts/reset-ui-tests.sh`'s `pkill` pattern to DerivedData paths so
  resetting the UI suite can no longer kill the installed `/Applications` copy.

#### Added — 2026-07-23

- Added Save to Tucked to macOS Share menus using the existing multiplatform Share extension, with link, text-link, and image capture.

#### Changed — 2026-07-23

- Changed the macOS **Save to Tucked** Share action to Quick Save: shared
  links and images now save immediately with no collection and Favorite off,
  avoiding the nested Collection menu inside Safari's Share surface. The
  interactive iPhone and iPad Share Sheet is unchanged.

#### Added — 2026-07-19

- Curated 7-swatch accent palette (Grape, Coral, Amber, Cherry, Fern, Teal, Graphite), each a `{dark, light}` hex pair resolved per OS appearance via dynamic NSColor/UIColor (`AppAccent.swift`). Swatch key stored in `@AppStorage("accentKey")` (default Grape) and applied as `.tint` at the app root; sidebar counts now use `.tint` instead of `.secondary`. New `AccentPickerView` sheet (swatch grid, tuned-for-both-themes footnote, preview rows) reachable from a new Appearance section in Settings.
- Custom sidebar selection styling: the selected row now draws a soft accent pill (accent at 0.16 opacity, rounded rect) plus a 3pt left accent capsule bar via `listRowBackground`; row icons and counts render in the resolved `AppAccent`, titles stay `.primary` (semibold when selected). Rows are plain `Button`s writing the selection binding, kept inside `List(selection:)` so `NavigationSplitView` still pushes detail on compact iPhone widths. Fixes native macOS selection painting from the compiled asset accent instead of the runtime-picked accent by owning the row background directly. Also replaced the stale blue `AccentColor` asset (#2E86FF) with the Grape pair (#8A4FE0 light / #B388FF dark). UI-test `destinationElement` helper updated to wait on Button rows.

#### Fixed — 2026-07-19

- Unified the library grid's adaptive column band across platforms. Mac and iOS/iPad previously used divergent ranges (Mac 220–320, iOS/iPad 160–260), producing a ~100pt "sawtooth" in card size as the window resized and making Mac/iPad density feel inconsistent. Both platforms now share `.adaptive(minimum: 160, maximum: 210)`; spacing stays platform-specific (14 iOS / 18 Mac). The minimum floor is held at 160 to preserve 2-column layout on iPhone SE (375pt width), so the band was narrowed by lowering the max rather than raising the min.
- Fixed a torn/cropped "window shade" artifact in the library grid during live iPadOS window resizing. `LazyVGrid` cells were retaining stale geometry mid-drag, which `BookmarkCard`'s clipped preview area then rendered against new cell bounds. The grid's `ScrollView` is now wrapped in a `GeometryReader` with a width-bucketed `.id()` that forces `LazyVGrid` to fully rebuild cells when available width crosses a ~20pt threshold, rather than relying on in-place relayout.
- Image viewer title is now inline; image cards show their added date instead of an empty domain line.
- Viewer and Get Info sheet minimum-size frames are macOS-only; they previously forced content wider than iPhone screens, clipping toolbars. Convention going forward: min-size frames on sheets belong in `#if os(macOS)`.
- Mac Settings sheet now uses grouped form style with a larger frame (520x480, was 440x360) so sections aren't cramped.
- Bookmark menu Share sheet now has an explicit Cancel toolbar button, so the window can be dismissed without Force Quit.
- App display name now reads "Tucked" and the Share Extension reads "Save to Tucked" on device home screens; both `Info.plist` files still had the pre-rename names ("Bookmarked Bookmarks" / "Save to Bookmark Collections") hardcoded, which silently overrode the `INFOPLIST_KEY_CFBundleDisplayName` build setting since both targets have `GENERATE_INFOPLIST_FILE = NO`. Removed the now-dead, mismatched build setting from `project.pbxproj` rather than leaving it as misleading cruft.

#### Verification

- Fresh 2026-07-23 verification: 52 unit tests and 10 UI tests pass on native macOS.
- Fresh 2026-07-23 iPhone 17 Pro simulator regression: the focused 14-test `ShareCaptureModelTests` suite passes. The complete iPhone simulator unit and UI suites were not rerun for the macOS Share extension work.
- Earlier, pre-2026-07-23 full-suite iPhone simulator results recorded 47 unit tests and 10 UI tests passing.
- Signed iOS app and Share Extension build and validate with matching App Group and CloudKit entitlements.
- Real-device CloudKit, Production schema, and TestFlight checks remain release gates; see `docs/verification/cloudkit-device-matrix.md`.
