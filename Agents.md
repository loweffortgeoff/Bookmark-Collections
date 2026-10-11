# Project: Tucked

Tucked is a native SwiftUI bookmark manager for iPhone, iPad,
and Mac. It saves HTTP and HTTPS links locally, captures links through an iOS
Share Extension, enriches them with webpage metadata, organizes them into zero
or one collection plus an independent Favorite state, and mirrors the private
library through SwiftData and CloudKit.

The product name is now Tucked. The project still uses `BookmarkCollections`
as its Xcode target and bundle identifier namespace — that rename is a
separate, not-yet-scheduled task. Do not rename Xcode identifiers, folders,
or the bundle ID unless a task explicitly asks for it.

## Codex Scope

- This file is the Codex-facing project guide for Tucked.
- Do not read or follow `CLAUDE.md` unless Geoff explicitly asks for it.
- Keep changes focused and prefer the smallest implementation that fits the
  existing architecture.
- Preserve the local-first capture experience: a valid URL must be durable
  locally before metadata or CloudKit work is allowed to matter.
- Push back on features that add accounts, hosted services, analytics,
  monetization, or third-party dependencies without an explicit product
  decision.

## Session Start

Before changing code, read the project context in:

- `README.md` - current architecture, requirements, commands, and release
  status.
- `CHANGELOG.md` - shipped and in-flight user-visible changes.
- `DECISIONS.md` - product and architecture decisions that should not be
  casually reversed.
- `TODO.md` - active backlog and explicitly deferred scope.

Read `docs/verification/cloudkit-device-matrix.md` when the task involves
CloudKit, signing, release readiness, TestFlight, or real-device behavior.
Read the design or implementation-plan documents under `docs/superpowers/`
only when historical product context is useful; implemented code and the
current README take precedence over an old plan.

## Product and Data Invariants

- The app supports iOS/iPadOS 18 and macOS 15, using Swift 6 and system Apple
  frameworks only.
- The app bundle identifier is `com.loweffortapps.BookmarkCollections`.
- The Share Extension bundle identifier is
  `com.loweffortapps.BookmarkCollections.ShareExtension`.
- Both targets share App Group
  `group.com.loweffortapps.BookmarkCollections` and CloudKit container
  `iCloud.com.loweffortapps.BookmarkCollections`.
- SwiftData is the local source of truth. CloudKit mirrors the private store;
  it is not an online API and must not block saving, browsing, or opening a
  bookmark.
- A bookmark belongs to zero or one `BookmarkCollection`. Favorites are an
  independent Boolean and must not be modeled as a collection.
- `NormalizedURL` accepts only HTTP and HTTPS URLs and removes fragments,
  default ports, and known tracking parameters before duplicate matching.
- Saving an existing normalized URL updates it; saving a recently deleted URL
  restores it. Independent duplicate records are reconciled deterministically:
  the earliest-created record keeps its UUID, Favorite is preserved if any
  duplicate is favorited, and the most recently modified title and collection
  win.
- Normal deletion sets `deletedAt` and moves the bookmark to Recently Deleted.
  Permanent deletion is explicit, and records older than 30 days are purged.
- Metadata and preview images are derived/cache data. A metadata failure must
  leave a valid bookmark with a usable URL/domain fallback.
- JSON backup preserves user-authored data, identifiers, dates, collections,
  and Favorite state. Netscape-compatible HTML is for portability. Preview and
  favicon binaries are intentionally not part of JSON backups.
- Do not add tags, multi-label organization, offline webpage archives, browser
  extensions, collaboration, custom accounts, non-CloudKit sync, analytics,
  telemetry SDKs, or StoreKit as part of v1.

## Architecture Map

- `BookmarkCollections/Data/` contains the CloudKit-compatible SwiftData
  models and `ModelContainerFactory`.
- `BookmarkCollections/Domain/` contains URL normalization, repository
  mutations, sorting/filtering helpers, metadata enrichment, import/export,
  backup representation, and sync-health reporting.
- `BookmarkCollections/Features/` contains the adaptive SwiftUI library,
  bookmark and collection editors, Settings, and Recently Deleted.
- `BookmarkCollections/Commands/` contains macOS menu commands and shortcuts.
- `BookmarkShareExtension/` contains the Share Sheet host and save UI. It must
  use the shared durable store and report completion only after the local save
  succeeds.
- `BookmarkCollectionsTests/` covers persistence, URL identity, repositories,
  metadata fallback, import/export, filtering, deletion, and Share Extension
  capture behavior.
- `BookmarkCollectionsUITests/` covers cross-platform navigation, seeded
  library states, accessibility, and user-facing flows.

The app creates an in-memory store automatically under XCTest and when the
`-ui-testing` launch argument is present. Normal app launches use the shared
App Group store with CloudKit enabled. On activation, the app reconciles URL
duplicates and enriches a bounded number of pending metadata records.

## UI and Accessibility

- Use SwiftUI and native Apple controls first: navigation, split views,
  sheets, forms, toolbars, menus, alerts, confirmation dialogs, context menus,
  swipe actions, and drag-and-drop.
- Use system fonts, SF Symbols, semantic colors, and light/dark appearance.
- Preserve the responsive visual-card library on iPhone, iPad, and Mac. Check
  both compact and wide layouts after changing grid or card geometry.
- The library grid intentionally uses a width-bucketed `.id()` workaround to
  force `LazyVGrid` to rebuild stale cells during continuous iPadOS window
  resizing. Do not remove or alter that behavior without testing live resize
  on iPad.
- Respect Dynamic Type, VoiceOver, keyboard focus, Mac commands, and native
  tap-target expectations. Card accessibility labels should communicate the
  title, domain, collection, and Favorite state when applicable.
- Destructive collection deletion and permanent deletion require confirmation.
  Soft-deleting an active bookmark does not require a second confirmation.
- Avoid onboarding and tiny overlay controls; empty states should explain the
  next useful action in context.

## Implementation Conventions

- Keep mutations in `BookmarkRepository` and `CollectionRepository` rather
  than duplicating persistence logic in views or the Share Extension.
- Keep metadata behavior behind `MetadataProviding`/`MetadataEnricher` so
  tests can use deterministic providers and the save path stays independent
  of network timing.
- Keep import/export behavior in the existing services. Reuse normalized URL
  identity and repository semantics for imported links instead of inventing a
  second duplicate policy.
- Preserve CloudKit compatibility: persisted model properties need defaults or
  optionality, relationships must remain compatible with the current schema,
  and large image data stays in external storage.
- Prefer `@AppStorage` for simple preferences and existing environment/
  SwiftData dependencies for app state. Do not introduce a new global store
  or service locator.
- Keep user-facing strings localizable and avoid hard-coded platform-specific
  layout assumptions.
- Do not edit the Xcode project file for ordinary source additions unless the
  project genuinely requires it; first verify how the current synchronized
  groups handle the file.
- Do not add a package dependency without explicit approval.

## Build and Test

The project is `BookmarkCollections.xcodeproj`; the main scheme includes the
app, Share Extension, unit tests, and UI tests. Set a development team for
both app targets when building a signed configuration.

```bash
# Build the signed iOS app and Share Extension
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'generic/platform=iOS'

# Run unit tests in the native macOS runner
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests

# Run UI tests in the native macOS runner
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsUITests
```

For iOS simulator coverage, replace the destination with an installed
simulator, for example:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  -only-testing:BookmarkCollectionsTests
```

Run unit and UI targets separately when diagnosing failures. Keep the macOS
UI runner code signed; disabling signing after a clean build can cause XCTest
to terminate the runner before it starts.

For documentation-only edits, `git diff --check` is the narrowest useful
validation. For source changes, run the smallest relevant test target and then
the broader unit/UI suites when the change crosses layers.

## Project Documentation

Codex may update these when a code change warrants it:

- `CHANGELOG.md` - concise user-visible or developer-relevant changes.
- `DECISIONS.md` - meaningful product or architecture decisions, using the
  existing Decision / Why / Alternative style.
- `TODO.md` - concise active work, backlog, or completed items.

Do not rewrite release or verification history just to make a session look
complete. Keep release-gate evidence in
`docs/verification/cloudkit-device-matrix.md`, and mention missing real-device
evidence rather than implying that simulator tests prove CloudKit sync.

## Release & Authorial Docs

Ownership splits by phase: the dev-session docs above (CHANGELOG.md,
DECISIONS.md, TODO.md) are covered in Project Documentation. ASC_LISTING.md
and RELEASE_NOTES.md don't exist yet — the project hasn't reached a release
pass. Once they exist, the release-pass skill owns them and reconciles them
at release time; do not edit them during a dev session.

## Session End

- Review the diff for accidental changes and run the narrowest useful
  validation.
- Update `CHANGELOG.md`, `DECISIONS.md`, or `TODO.md` only when the work
  materially changes what those files document.
- Do not claim CloudKit production readiness from a local build. The current
  release gates are the real-device CloudKit matrix, Production schema
  deployment, and the final TestFlight/new-account check.
