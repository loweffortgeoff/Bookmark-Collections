# CLAUDE.md — BookmarkCollections

Project notes for BookmarkCollections. General guidelines live in `../CLAUDE.md`.

# Development Commands

## Build Verification

Both schemes must build — `BookmarkCollections` (app) and `BookmarkShareExtension`
(share extension). Nine app files compile into the extension target:

- `Data/Bookmark.swift`, `Data/BookmarkCollection.swift`, `Data/ModelContainerFactory.swift`
- `Domain/BookmarkLimit.swift`, `Domain/BookmarkRepository.swift`, `Domain/ImageDownsampler.swift`,
  `Domain/MetadataProvider.swift`, `Domain/NormalizedURL.swift`,
  `Domain/ShareStorageDiagnostics.swift`

So an app-only build passes while the share extension is broken. Always verify
both. This is the whole save path — the extension writes bookmarks through the
same repository and SwiftData container as the app, so a model or repository
change breaks sharing from Safari without touching an extension file.

Use `-destination 'generic/platform=iOS Simulator'` — no simulator boot, faster,
and still catches compile and link errors for both targets.

```
xcodebuild -project BookmarkCollections.xcodeproj -scheme "BookmarkCollections" -destination 'generic/platform=iOS Simulator' build
xcodebuild -project BookmarkCollections.xcodeproj -scheme "BookmarkShareExtension" -destination 'generic/platform=iOS Simulator' build
```

Do not pass `-derivedDataPath` for ad hoc builds — keep the default
DerivedData. If a script needs its own folder, end the folder name in
`.noindex` (for example `build/MyTask.noindex`). Spotlight indexes every
`Tucked.app` under `build/`, so per-task folders fill a "Tucked" search with
duplicate apps (cleaned up 2026-11-18: 19 copies).

Leave the output verbose — don't add `-quiet`. Error parsing (build-runner's
included) tails the log for the first `error:`, and `-quiet` strips the context
that makes the first error findable.

## Testing Notes

- **MacBook: add `-allowProvisioningUpdates` to macOS builds and tests.** The
  MacBook has no local Mac development profiles, so `-destination
  'platform=macOS'` fails with "No profiles for
  'com.loweffortapps.BookmarkCollections' were found" without it (confirmed
  2026-11-26). iOS Simulator builds don't need it.
- **Fresh simulator: the first StoreKit audit run shows a Sandbox sign-in.** On
  a newly created or erased simulator, the first `Tucked Audit` run raises
  "Sign in to Apple Account" and the purchase tests hang. Press Cancel (never
  sign in), stop the run, and rerun; the warmed simulator then passes
  `StorefrontAuditTests` with no dialog (2026-11-26). The same dialog can
  appear on macOS with Geoff's account pre-filled — cancel it.
- **Expected skips.** Unit suites (`BookmarkCollectionsTests`) skip 16 tests:
  15 `StorefrontAuditTests` (they run only under `Tucked Audit`) and
  `ScreenshotSeedTests`. UI suites skip 1:
  `PaywallFlowAuditTests.testPurchaseClearsRestoreErrorAndUnlocksRunningApp`
  (also `Tucked Audit` only). Any other skip is new — find out why.
