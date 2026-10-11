# CLAUDE.md — BookmarkCollections

Project notes for BookmarkCollections. General guidelines live in `../CLAUDE.md`.

# Development Commands

## Build Verification

Both schemes must build — `BookmarkCollections` (app) and `BookmarkShareExtension`
(share extension). Eight app files compile into the extension target:

- `Data/Bookmark.swift`, `Data/BookmarkCollection.swift`, `Data/ModelContainerFactory.swift`
- `Domain/BookmarkRepository.swift`, `Domain/ImageDownsampler.swift`,
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

Leave the output verbose — don't add `-quiet`. Error parsing (build-runner's
included) tails the log for the first `error:`, and `-quiet` strips the context
that makes the first error findable.
