---
name: verify-tucked
description: Launch Tucked (Xcode project BookmarkCollections, iOS SwiftUI bookmark manager) in an iOS Simulator with a seeded in-memory library, drive it through the real UI with agent-device, and capture screenshots plus accessibility snapshots as proof. Use when a change to the library, add-link, search, favorites, delete/restore, or Settings screens needs confirming in the running app, not just in tests.
---

# Verify Tucked (iOS Simulator)

Surface: the native iOS app, driven through the simulator's accessibility tree with `agent-device`. The macOS app and the Share Extension are out of scope here (see Gotchas).

Everything below runs from the repo root. `$SKILL` means `.claude/skills/verify-tucked`.

## Launch

1. Get a device. Call `device_list`, pick an iPhone simulator that is **not already booted** (the user's own sessions may be using the booted ones), then `device_open` it. It returns an `agent-device` command path. Export it:
   ```
   export AD=/Users/<you>/.t3/userdata/device/targets/t3-<id>/agent-device
   export RUN_ID=$(date +%Y%m%d-%H%M%S)
   ```
   Shell state does not persist between tool calls in some harnesses: set `AD` and `RUN_ID` in every call that runs a helper (a stable `RUN_ID` keeps one run's evidence in one folder).
2. Build, install, launch:
   ```
   $SKILL/scripts/launch.sh
   ```
   It builds the `BookmarkCollections` scheme into `build/VerifyDerivedData` (gitignored, reused across runs), installs `Tucked.app`, and launches with `-ui-testing -free-limit 100`.
   - `-ui-testing` swaps in an **in-memory** SwiftData store with CloudKit off, and seeds the library (below). Every launch starts from the same state; nothing persists across launches.
   - `-free-limit 100` lifts the 10-item free cap. The seed holds 7 active items, so a few adds would otherwise raise the paywall. Drop the flag only when verifying the paywall (set `FREE_LIMIT=` empty or a small number).
   - Ready means the `All Items` grid is on screen with the seeded cards. `launch.sh` waits for that and exits non-zero otherwise.
3. First `agent-device` use on a device builds an XCTest runner and can take a couple of minutes.

**Seed (baseline for every feature file):** sidebar counts All Items 7, Images 1, Links 5, Snippets 1, Favorites 1; collection `Reading` (1 item); Recently Deleted holds `Seeded Deleted`. Cards: `Seeded Active` (favorite, in Reading), `Seeded Snippet`, `Seeded Image`, `Landscape 16:9 Preview`, `Square Preview`, `Wide`, `Portrait Preview With a Deliberately Long Two Line Title`.

## Doctor

```
$SKILL/scripts/doctor.sh
```
Read-only. Checks that `$AD` is set and responds, a build exists at `build/VerifyDerivedData` with the right bundle id (it prints the build time), and Tucked is the foreground app showing the seeded library. Prints `OK` or the first failed check. Run it first whenever anything looks off. If it fails, re-run `launch.sh`.

## Drive

Use `$AD` for every tap, text entry, screenshot. Do not use `simctl`/`idb` for UI actions.

- `$AD snapshot -i` prints the interactive tree with `@eN` refs. **Refs are renumbered after every screen change**, so re-snapshot before using a ref, or prefer selectors, which are stable: `label="<exact text>"`, optionally `role=button|cell|text|search` or `editable=true`. Values with spaces need quotes inside the selector.
- `$AD press 'label="Add Link" role=button' --settle` taps and returns the settled diff.
- `$AD fill 'label="Search bookmarks" editable=true' "text"` types into a field (the placeholder doubles as its label).
- `$AD longpress 'label="Seeded Active"' --settle` opens a card's context menu.
- Sidebar rows expose both a cell (`label="Favorites" role=cell`, tap this) and an identifier node (`label="destination.favorites"`). Identifiers in the app: `destination.{allItems,images,links,snippets,favorites,forgotten,collections,recentlyDeleted}`, `library.*`, `bookmark.<id>`, `selection.toggle`, `settings.*`.
- Navigation: the nav-bar button `label="Bookmarks"` goes back to the sidebar. The last selected destination is remembered, so always go to the sidebar and pick the destination explicitly before driving a feature.
- The accessibility tree can lag a settle: after a filter or destination change, wait ~1-2 s and re-snapshot before concluding an element is missing.

Feature recipes are in `features/` (read `features/README.md` first).

## Evidence

Artifacts land in `build/verify-artifacts/$RUN_ID/` (gitignored, never deleted by cleanup).

```
$SKILL/scripts/evidence.sh <feature-id> <step-name>
```
writes `<feature>-<step>.png` (screenshot) and `<feature>-<step>.snapshot.txt` (accessibility tree) there. Capture the state **before** the action, then **after**; a final screen alone does not prove the action happened.

Proof standards:
- Drive the real UI path (Add menu, context menu, sidebar). No setters, no test-only hooks beyond the launch flags above.
- Prove side effects through a second view: the action's result must also show in sidebar counts, another destination, or a reopened item. The store is in-memory, so there are no files or DB rows to inspect, and a count/destination cross-check is the stand-in.
- Link metadata fetch needs network and is not part of the save path. A saved link shows its domain as the title until metadata arrives; verify the save, not the fetched title.
- Anything the iOS simulator cannot exercise (CloudKit sync, Safari Share Sheet, StoreKit sandbox) is **not** verified by this skill. Say so instead of inferring.

## Cleanup

```
$SKILL/scripts/cleanup.sh
```
Closes the agent-device session for `com.loweffortapps.BookmarkCollections` on the simulator you opened. It does not shut the simulator down (you did not necessarily boot it), does not delete `build/VerifyDerivedData` (a warm build cache), and never touches `build/verify-artifacts/`. Then call `device_close` for the device you opened. Run cleanup after failed attempts too.

## Helpers

| Script | Invocation | Does |
| --- | --- | --- |
| `scripts/launch.sh` | `$SKILL/scripts/launch.sh` (needs `$AD`) | build + install + launch + wait for seeded grid |
| `scripts/doctor.sh` | `$SKILL/scripts/doctor.sh` | read-only health check |
| `scripts/evidence.sh` | `$SKILL/scripts/evidence.sh <feature> <step>` | screenshot + snapshot into the artifacts dir |
| `scripts/cleanup.sh` | `$SKILL/scripts/cleanup.sh` | stop the app session, keep artifacts |

## Gotchas

- Isolation: one app instance per simulator. If `device_open` reports the device is in use, pick another simulator; never drive one another session holds. Never kill processes by name.
- The default simulator build skips signing, so entitlements (App Group, CloudKit, iCloud) are inactive; Settings correctly shows `iCloud temporarily unavailable`.
- Verification of the macOS app is `xcodebuild test -destination 'platform=macOS' -only-testing:BookmarkCollectionsUITests` (see `README.md`); the Share Extension needs a Safari share on a real build. Both are outside this skill. Still run both `xcodebuild` build schemes from `CLAUDE.md` when model/repository code changed.
