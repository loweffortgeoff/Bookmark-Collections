# CloudKit and Release Verification Matrix

## Remaining bug package — 2026-10-24 local work

Approved package: `fix/remaining-bug-fixes`, based on `main` at `158fbb3`. Implementation covers Share re-save preservation, accessibility-size grid/editor corrections, Mac failure recovery and kind-aware sharing, and explicit build settings. Build 9 does not validate this changed source. Local evidence and exact failures are in `.superpowers/sdd/2026-10-23-remaining-bug-fixes/`; the implementation plan tracks unfinished local verification.

Physical iPhone B2 remains **pending**. On the changed build, record device/OS/build/host, test Safari links and Photos images, and capture `ShareStorage`/`ShareSave` error domain/code chains if storage fails. Inspect app/extension App Group and CloudKit entitlements for that exact build. No store reset, schema change, or signing change was made as a speculative repair.

Acceptance still needs real-host duplicate re-share on each platform; Mac free-limit Open Tucked/Cancel and failed-open behavior; failure surfaces in light/dark and supported text sizes; and physical iPad long-content/narrow/wide/live-resize checks. Use an approved disposable library. Production purchase/restore, immediate Mac unlock, cross-platform ownership, fresh-account sync, and offline conflicts remain separate submission gates. No new upload, merge, push, or review submission is authorized by this package.


Last updated: 2026-10-23 (TestFlight availability verified; device evidence retains its original dates)

## Current local validation — 2026-10-23

The paywall/JSON fix package passes 169 checks on Mac and 169 on iPhone 18 Pro / iOS 27.0, with signed Release builds and independent review. See the [audit follow-up](2026-10-23-branch-paywall-audit.md#approved-fix-follow-up). Physical Share capture, current-build sandbox/TestFlight purchase/restore and cross-device access, fresh-account Production sync, and offline/conflict checks remain acceptance gates. No device or CloudKit gate was closed by local tests.

## TestFlight candidate — 2026-10-23

Source `f34b8c6`, scheme **Tucked Release**, configuration Release: iOS and native macOS **1.0 (9)** uploaded, processed `VALID`, and verified `IN_BETA_TESTING` in the existing internal group. What to Test and export compliance are saved. Both packages remain App Store eligible. No App Review submission, build selection for App Review, push, or merge occurred.

Built on the Mac mini, macOS 27.0.1 / Xcode 27.1. Distribution signatures and app/extension identifiers, versions, paywall configuration, App Group, and Production CloudKit entitlements pass inspection; iOS push uses production. Build number 9 was a command-line override. App source and project remain unchanged from `f34b8c6`.

The [JSON test pack](fixtures/Tucked-TestFlight-1.0-9-JSON-tests.zip) contains five numbered files and [device instructions](fixtures/2026-10-23-testflight/README.md). One targeted native Mac test exercised all five files through the actual importer and passed. Its first invocation hit the test target's macOS 14 default; overriding the test deployment target to 15 resolved compilation. No app code changed. Evidence: `.superpowers/sdd/2026-10-23-testflight/` (ignored).

Device purchase/restore, the Mac same-session unlock, Share capture, cross-platform purchase access, and Production CloudKit gates remain open. Tucked for Life is `READY_TO_SUBMIT`; both App Store platform versions remain `DEVELOPER_REJECTED`. These states are separate from internal TestFlight availability.

## Historical release status

Automated implementation verification is complete. Most of the real-device same-account matrix below is confirmed across iPhone, iPad, and Mac, but Mac-originated create-bookmark propagation remains pending. Destructive offline conflict exercises, CloudKit Production schema deployment, Safari HTML import, and the new-account TestFlight check are also still pending. Simulator or local build success is not recorded as CloudKit synchronization evidence.

Mac-originated changes (collection rename, permanent delete, favorite toggle, move to collection) initially required backgrounding/relaunching a receiving iPhone or iPad to appear, while iPhone-originated changes always appeared live. Root cause: the app was never actually receiving CloudKit's silent push notifications, because the Push Notifications capability (and `aps-environment` entitlement) was never enabled on the target — `registerForRemoteNotifications()` alone is a no-op without it. The only sync trigger was the app becoming active. Fixed in `e2b1b24` by enabling the Push Notifications capability, adding `aps-environment: development` to the entitlements, and adding registration/receipt logging to `AppDelegate`. Retested on real devices post-fix: live sync now works without backgrounding. Note the entitlement is currently `development` in source, but that's expected — the flip to `production` happens at export/upload, not in the local `.xcarchive`. Confirmed indirectly on 2026-08-29: iOS and Mac TestFlight builds were archived and uploaded, and a Mac-originated image change synced live to a second device that was never reopened/foregrounded — the same live-push behavior the `e2b1b24` fix produced in development, now reproduced on the Production TestFlight build. This closes the aps-environment open question from the CloudKit Production release gate below.

## Completed evidence

| Area | Result | Evidence |
| --- | --- | --- |
| macOS unit tests | Pass | 52 tests, 0 failures on 2026-07-23 |
| macOS UI tests | Pass | 10 tests, 0 failures on 2026-07-23 using the required signed runner |
| iPhone simulator Share-capture regression | Pass | 14 focused `ShareCaptureModelTests`, 0 failures on iPhone 17 Pro / iOS 26.5 on 2026-07-23; the complete simulator suites were not rerun |
| iPhone simulator unit tests (historical) | Pass | 37 tests, 0 failures on iPhone 17 Pro / iOS 26.5 during the 2026-07-18 verification pass |
| iPhone simulator UI tests (historical) | Pass | 8 tests, 0 failures on iPhone 17 Pro / iOS 26.5 during the 2026-07-18 verification pass |
| Static analysis | Pass | `xcodebuild analyze` succeeded; launch-screen and orientation validation warnings were corrected |
| Signed device build | Pass | App and Share Extension signed and embedded successfully |
| Entitlement inspection | Pass | Both products contain the same App Group and private CloudKit container identifiers |
| iOS Share Extension live flow | Pass | Safari Share Sheet loaded an exact URL, Save dismissed only after persistence, and the main app immediately displayed it |
| macOS Share extension build and registration | Pass | Signed `platform=macOS` build succeeded; the embedded extension has the shared App Group/CloudKit entitlements plus App Sandbox and outbound networking, and `pluginkit` registers it as `Save to Tucked` |
| macOS link Share flow | Pass | With Tucked closed, Safari Quick Save persisted the exact public URL documented below, dismissed without success-time controls, and produced a no-collection, Favorite-off bookmark |
| macOS image Share flow (initial confirmation UI) | Pass (historical) | Before Quick Save replaced the macOS confirmation UI, Finder shared the repository app icon into Personal as a Favorite; Tucked rendered the image card and the active image count increased by one |
| macOS image panel preview visibility (initial confirmation UI) | Unverified, superseded | The former preview was intentionally AX-hidden and ShareKit omitted the protected remote panel from Computer Use screenshots; current Quick Save has no preview UI |
| macOS Quick Save failure and retry | Pass (automated) | Unsupported-input and save-failure retry tests pass; no ordinary live host exposed the extension for unsupported content during the Quick Save verification |
| JSON backup recovery | Pass (automated) | Round trip preserved bookmark/collection UUIDs, URL, title, order, Favorite, and dates in a fresh in-memory store |
| HTML portability format | Pass (automated) | Netscape header, escaping, folders, Favorite tags, and non-duplication are covered |
| Dark + maximum Dynamic Type | Pass (automated UI) | Card accessibility and Settings checks passed in dark appearance at accessibility XXXL; simulator was restored afterward |
| VoiceOver semantics | Pass (automated) | Card exposes title, domain, collection, and Favorite state; decorative preview content is hidden |

Note: a combined unsigned macOS clean-test invocation can cause XCTest to SIGKILL its UI runner before bootstrap. Unit tests passed in that clean invocation; the full UI target passed immediately when rebuilt with normal signing. This is a test-harness signing condition, not an app crash.

## macOS Quick Save verification — 2026-07-23

The signed deterministic build at commit `51393ad` was produced with:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/QuickSaveDerivedData
```

The build succeeded. Strict nested code-signing verification passed, and the
embedded extension retained App Sandbox, outbound network access, App Group
`group.com.loweffortapps.BookmarkCollections`, and CloudKit container
`iCloud.com.loweffortapps.BookmarkCollections`. `pluginkit` registered that
extension as `Save to Tucked`.

The focused 14-test native macOS `ShareCaptureModelTests` run then built the
same source state into Xcode's default DerivedData location. ShareKit selected
that registered product for the live Safari flow:

```text
/Users/geoffreysilva/Library/Developer/Xcode/DerivedData/BookmarkCollections-cmvirhxqbwkgthazaqqrktobwfhc/Build/Products/Debug/BookmarkCollections.app
```

All Tucked and Share extension processes were confirmed closed before Safari
shared:

```text
https://example.com/?tucked-macos-quick-save=20260723
```

Choosing **Save to Tucked** returned directly to Safari in under one second.
No Collection picker, Favorite toggle, Save button, or intermediate AX-visible
confirmation panel appeared, and the containing app remained closed. Opening
Tucked increased All Items from 24 to 25 and Links from 18 to 19. The new
Example Domain card had no organization suffix; Get Info reported Collection
`None` and Favorite off. The unique verification bookmark was then
soft-deleted, returning the active counts to their prior values.

No ordinary host offered the extension for unsupported input during this live
pass, so no live failure-panel claim is made. Automated tests verify that
unsupported input and save failure do not complete the request and that a
second Quick Save attempt can succeed.

This verifies local macOS Share capture. It does not provide CloudKit
Production, TestFlight, or cross-device synchronization evidence.

## Initial macOS Share extension verification — 2026-07-23

The signed build used for the final live flow was produced from commit `3fd8ead`
with:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS'
```

The build succeeded. ShareKit selected the default DerivedData product at:

```text
/Users/geoffreysilva/Library/Developer/Xcode/DerivedData/BookmarkCollections-cmvirhxqbwkgthazaqqrktobwfhc/Build/Products/Debug/BookmarkCollections.app
```

While both the Safari link panel and Finder image panel were open, `ps` and
`lsof` reported the live extension executable and mapped debug dylib inside
that app. This is runtime evidence for the default DerivedData product, not
the separate deterministic worktree build used during earlier signing checks.

The embedded extension is Apple Development signed as
`com.loweffortapps.BookmarkCollections.ShareExtension`, team
`2R5TZD4XAH`. Effective entitlements include App Sandbox, App Group
`group.com.loweffortapps.BookmarkCollections`, CloudKit container
`iCloud.com.loweffortapps.BookmarkCollections`, and outbound network client
access. `pluginkit -mAvvv -p com.apple.share-services` registered that exact
embedded path as the macOS `Save to Tucked` Share service.

Live host evidence, with Tucked confirmed closed before each first save:

- Safari shared
  `https://example.com/?tucked-macos-share=20260723-task4-final`. The panel
  showed `Example Domain` and the exact URL; Home and Favorite were selected,
  the AX-visible Save button dismissed the panel, and Tucked showed one
  matching Home/Favorite card. Re-sharing the same URL retained one store
  record with the same primary key and a later modification date.
- Finder shared
  `BookmarkCollections/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
  Finder showed the selected 758 KB PNG preview; the extension loaded its
  Image section, Personal and Favorite were selected, and Save dismissed the
  panel. Tucked then visibly rendered the pocket-star image card with the
  non-empty title `Image — Jul 23, 2026`, Personal, and Favorite; the active
  image count moved from 5 to 6 and the stored preview payload was non-empty.
  The extension-panel preview itself was not directly observable because it
  is AX-hidden and ShareKit omitted the protected remote panel from Computer
  Use screenshots; that preview-visibility sub-check remains unverified.
- Safari opened
  `https://example.com/?tucked-macos-share=20260723-task4-cancel`; the
  AX-visible body-local Cancel button dismissed the panel and a read-only
  shared-store query confirmed zero records for that normalized URL.

These checks verify local macOS Share capture and do not provide CloudKit
Production, TestFlight, or cross-device synchronization evidence.

## Real-device same-account matrix

Use one iPhone, one iPad, and one Mac signed into the same development iCloud account. Record timestamps and propagation latency in Notes.

| Operation | iPhone | iPad | Mac | Notes |
| --- | --- | --- | --- | --- |
| Create bookmark | Confirmed | Confirmed | Pending | Shared an App Store Connect page via the Share Extension on iPad; synced to iPhone. Mac not yet exercised for this row. |
| Toggle Favorite | Confirmed | Confirmed | Confirmed | Favorited on iPhone, synced to iPad and Mac; unfavorite also synced. |
| Move to collection | Confirmed | Confirmed | Confirmed | Moved into a collection on iPad; collection and membership synced to iPhone and Mac. |
| Rename collection | Confirmed | Confirmed | Confirmed | Renamed on Mac; originally needed a relaunch on iPad to show live — root-caused to missing Push Notifications capability, fixed in `e2b1b24`, retested live post-fix. |
| Soft delete | Confirmed | Confirmed | Confirmed | Deleted on iPhone; appeared in Recently Deleted on iPad and Mac live, no relaunch needed. |
| Restore | Confirmed | Confirmed | Confirmed | Restored on iPhone; removed from Recently Deleted on iPad and Mac live, no relaunch needed. |
| Permanent delete | Confirmed | Confirmed | Confirmed | Permanently deleted on Mac; originally needed a relaunch on iPad to show live — same root cause and fix as the collection rename row, retested live post-fix. |
| Preview arrival | Confirmed | Confirmed | Confirmed | Favicon and preview image for the App Store Connect bookmark visible on all three devices. |
| Relaunch persistence | Confirmed | Confirmed | Confirmed | Force-quit and relaunched on all three; bookmarks, collections, and favorite state all persisted locally. |

## Offline conflict matrix

1. Disconnect two devices from all networks.
2. Edit the same existing bookmark differently on each device; make the later edit’s title and collection unambiguous.
3. Reconnect both devices and return the app to the foreground.
4. Confirm the most recently modified record wins and all three devices converge.
5. Repeat by saving the same normalized URL independently on both offline devices with different generated UUIDs, collections, titles, and Favorite choices.
6. Confirm one earliest-created canonical record remains, Favorite is true if either copy was true, and the latest title/collection wins.

| Scenario | iPhone | iPad | Mac | Result / latency |
| --- | --- | --- | --- | --- |
| Conflicting edits to one record | Pending | Pending | Pending | |
| Independent same-URL saves | Pending | Pending | Pending | |
| Offline soft delete vs edit | Pending | Pending | Pending | |

## Remaining manual quality checks

| Check | Status | Notes |
| --- | --- | --- |
| Share Sheet with network disabled | Pending | Local-store behavior is covered by tests; a physical airplane-mode pass is still required |
| Metadata failure fallback | Pass (automated) | Valid URL remains durable with pending/failed metadata |
| Empty states and destructive confirmations | Pass (automated UI) | iPhone and Mac suites |
| Keyboard-only Mac commands | Pending manual | Commands compile and focus/selection behavior passed review; complete Tab/menu exercise |
| VoiceOver spoken order | Pending manual | Semantic values pass automated accessibility queries |
| Light/dark appearance | Pass (automated UI) | Light full suite; dark focused accessibility suite |
| Accessibility text sizes | Pass (automated UI) | Accessibility XXXL focused suite |
| JSON export to fresh store | Pass (automated) | Actual system file panels still need final human smoke test |
| HTML import into Safari | Pending manual | Would modify the user’s Safari bookmarks |

## CloudKit Production release gate

- [ ] Inspect the Development schema in CloudKit Console.
- [ ] Verify only intended bookmark and collection record types/fields exist.
- [x] Deploy the schema to Production. (Confirmed on device 2026-08-28: Production schema carries `lastOpenedAt` and `snippetBody`.)
- [x] Archive and upload a TestFlight build. (2026-08-29: iOS and Mac archives both uploaded and finished processing; internal TestFlight is live.)
- [ ] With a fresh iCloud account, create the first bookmark and verify Production sync to a second device. (2026-08-29 live-sync check used the existing dev account, not a fresh one — still open.)
- [ ] Date and sign off this document before marking v1 release-ready.
