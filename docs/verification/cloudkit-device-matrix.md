# CloudKit and Release Verification Matrix

Last updated: 2026-07-18 (America/New_York)

## Release status

Automated implementation verification is complete. Real-device synchronization, destructive offline conflict exercises, CloudKit Production schema deployment, Safari HTML import, and the new-account TestFlight check are still pending. Simulator or local build success is not recorded as CloudKit synchronization evidence.

Paired hardware was discoverable during this pass (two iPhones and one iPad Pro), but the required flows need hands-on device interaction and account-level CloudKit Console access. No app was installed and no Production schema was changed during this automated pass.

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
| Create bookmark | Pending | Pending | Pending | |
| Toggle Favorite | Pending | Pending | Pending | |
| Move to collection | Pending | Pending | Pending | |
| Rename collection | Pending | Pending | Pending | |
| Soft delete | Pending | Pending | Pending | |
| Restore | Pending | Pending | Pending | |
| Permanent delete | Pending | Pending | Pending | |
| Preview arrival | Pending | Pending | Pending | |
| Relaunch persistence | Pending | Pending | Pending | |

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
