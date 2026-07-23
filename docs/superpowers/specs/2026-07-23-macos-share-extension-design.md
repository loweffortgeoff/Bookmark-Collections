# macOS Share Extension Design

**Date:** 2026-07-23

## Goal

Give Tucked full Share Sheet parity on macOS. From a standard macOS Share menu,
the user can send one web link, text containing a valid web link, or one image
to Tucked, review the item, choose a collection and Favorite state, and save it
without opening the main app.

The macOS path must preserve Tucked's local-first guarantee: the extension
dismisses successfully only after the shared SwiftData store has durably saved
the item. Metadata enrichment and CloudKit mirroring must not block that save.

## Product Experience

The existing extension remains named **Save to Tucked**. It is available in
standard macOS Share menus when the host supplies one of the supported input
types:

- one HTTP or HTTPS URL;
- text containing an HTTP or HTTPS URL; or
- one image.

Choosing the extension opens a compact native panel titled **Save Bookmark**.
The panel matches the iOS flow and includes:

- a link or image preview;
- a Collection picker with None as an option;
- an independent Favorite toggle;
- Cancel and Save actions; and
- inline loading, saving, and failure states.

Save is disabled until the extension has loaded a supported item. A successful
save dismisses the system request. Unsupported or unreadable input, failure to
open the shared store, and repository save failure keep the panel open and
offer an actionable Retry or Cancel path. No partial bookmark may be created.

The containing Tucked app does not need to be running.

## Architecture

The existing `BookmarkShareExtension` target becomes a multiplatform iOS and
macOS Share extension instead of introducing a second extension target.
The target retains the current product and bundle identifier namespace.

Shared extension components remain responsible for the same narrow jobs:

- `ShareCaptureModel` loads and validates providers, coordinates metadata, and
  calls the repository-backed save action.
- `ShareCaptureView` presents the confirmation form and capture state.
- `ModelContainerFactory` opens the shared App Group SwiftData store with
  CloudKit mirroring enabled.
- `BookmarkRepository` owns link normalization, duplicate update/restore
  semantics, image creation, collection assignment, and Favorite state.

Platform-specific code is limited to hosting and native image bridging:

- iOS continues to use `UIViewController`, `UIHostingController`, and
  `UIImage`.
- macOS uses `NSViewController`, `NSHostingController`, and `NSImage`.

The target's supported platforms, embedding relationship, deployment target,
SDK selection, signing settings, and entitlements will be configured so the
appropriate extension binary is embedded in the iOS or macOS containing app.
Both extension variants use the existing App Group and CloudKit container.
The macOS extension receives any macOS-specific sandbox/signing entitlements
required by Apple's Share extension runtime without changing the product's
storage identifiers.

## Save and Enrichment Flow

1. The host app starts **Save to Tucked** with extension items.
2. The platform host flattens their attachments into `NSItemProvider` values.
3. `ShareCaptureModel` checks direct URLs first, text URLs second, and images
   third, preserving the current deterministic input precedence.
4. A valid link is normalized before it becomes saveable. A valid image is
   downsampled through `ImageDownsampler` before persistence.
5. For links, metadata enrichment may begin while the confirmation panel is
   open. Metadata is optional derived data.
6. The user selects a collection and Favorite state, then chooses Save.
7. `BookmarkRepository` writes to the shared local SwiftData store using the
   existing update, restore, duplicate, and image semantics.
8. Only after that local write succeeds does the extension complete and
   dismiss. CloudKit mirrors the store independently.

If metadata is absent or fails, a link still saves with its usable URL/domain
fallback. If the local write fails, the extension reports failure and does not
claim success.

## Testing and Verification

Automated verification will cover the platform-neutral capture and persistence
logic, including:

- direct URL capture;
- URL extraction from shared text;
- image validation and downsampling;
- collection and Favorite assignment;
- existing-link update/restore behavior;
- unsupported input;
- storage/save failure; and
- completion only after a successful save.

Build verification will cover:

- the signed macOS containing app with its embedded Share extension;
- the signed iOS containing app with its embedded Share extension;
- the native macOS unit suite; and
- the existing iOS Share extension tests or the narrowest equivalent simulator
  regression suite.

Signing inspection will confirm that the macOS app and extension use compatible
App Group and CloudKit entitlements. Live macOS verification will share:

- a web link from Safari; and
- an image from at least one standard image-producing host,

with Tucked closed before capture. The resulting items must be visible after
opening Tucked, with the selected collection and Favorite state intact.

Real-device CloudKit or release-readiness documentation will record only
evidence actually observed. A successful local build or local Share flow is
not proof of production CloudKit readiness.

## Documentation Impact

Implementation updates will:

- revise `README.md` to describe Share Sheet capture on iOS and macOS;
- add the macOS Share capability to `CHANGELOG.md`;
- supersede the prior v1 decision that image capture is iOS-only in
  `DECISIONS.md`;
- reconcile Mac image-import backlog entries in `TODO.md` without implying
  that Share Sheet capture also implements drag-and-drop or file import; and
- update `docs/verification/cloudkit-device-matrix.md` only with completed
  verification evidence.

## Out of Scope

- multiple items in one Share request;
- drag-and-drop capture;
- Files or Photos picker import;
- a browser extension;
- a background capture service;
- changes to link normalization, collection membership, Favorites, deletion,
  or CloudKit conflict semantics;
- redesigning the existing iOS Share flow; and
- renaming Xcode targets, bundle identifiers, folders, or the App Group.
