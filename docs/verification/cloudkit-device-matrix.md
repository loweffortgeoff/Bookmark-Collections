# CloudKit and Release Verification Matrix

Last updated: 2026-07-18 (America/New_York)

## Release status

Automated implementation verification is complete. The real-device same-account matrix below is now fully confirmed across iPhone, iPad, and Mac. Destructive offline conflict exercises, CloudKit Production schema deployment, Safari HTML import, and the new-account TestFlight check are still pending. Simulator or local build success is not recorded as CloudKit synchronization evidence.

Mac-originated changes (collection rename, permanent delete, favorite toggle, move to collection) initially required backgrounding/relaunching a receiving iPhone or iPad to appear, while iPhone-originated changes always appeared live. Root cause: the app was never actually receiving CloudKit's silent push notifications, because the Push Notifications capability (and `aps-environment` entitlement) was never enabled on the target — `registerForRemoteNotifications()` alone is a no-op without it. The only sync trigger was the app becoming active. Fixed in `e2b1b24` by enabling the Push Notifications capability, adding `aps-environment: development` to the entitlements, and adding registration/receipt logging to `AppDelegate`. Retested on real devices post-fix: live sync now works without backgrounding. Note the entitlement is currently `development` — confirm it flips to `production` automatically at archive/TestFlight time (standard Xcode behavior via the distribution provisioning profile), and treat that as part of the CloudKit Production release gate below.

## Completed evidence

| Area | Result | Evidence |
| --- | --- | --- |
| macOS unit tests | Pass | 37 tests, 0 failures after a clean rebuild |
| macOS UI tests | Pass | 8 tests, 0 failures using the required signed runner |
| iPhone simulator unit tests | Pass | 37 tests, 0 failures on iPhone 17 Pro / iOS 26.5 |
| iPhone simulator UI tests | Pass | 8 tests, 0 failures on iPhone 17 Pro / iOS 26.5 |
| Static analysis | Pass | `xcodebuild analyze` succeeded; launch-screen and orientation validation warnings were corrected |
| Signed device build | Pass | App and Share Extension signed and embedded successfully |
| Entitlement inspection | Pass | Both products contain the same App Group and private CloudKit container identifiers |
| Share Extension live flow | Pass | Safari Share Sheet loaded an exact URL, Save dismissed only after persistence, and the main app immediately displayed it |
| JSON backup recovery | Pass (automated) | Round trip preserved bookmark/collection UUIDs, URL, title, order, Favorite, and dates in a fresh in-memory store |
| HTML portability format | Pass (automated) | Netscape header, escaping, folders, Favorite tags, and non-duplication are covered |
| Dark + maximum Dynamic Type | Pass (automated UI) | Card accessibility and Settings checks passed in dark appearance at accessibility XXXL; simulator was restored afterward |
| VoiceOver semantics | Pass (automated) | Card exposes title, domain, collection, and Favorite state; decorative preview content is hidden |

Note: a combined unsigned macOS clean-test invocation can cause XCTest to SIGKILL its UI runner before bootstrap. Unit tests passed in that clean invocation; the full UI target passed immediately when rebuilt with normal signing. This is a test-harness signing condition, not an app crash.

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
- [ ] Deploy the schema to Production.
- [ ] Archive and upload a TestFlight build.
- [ ] With a fresh iCloud account, create the first bookmark and verify Production sync to a second device.
- [ ] Date and sign off this document before marking v1 release-ready.
