# macOS Quick Save Design

**Date:** 2026-07-23

## Goal

Make capture from Safari and other macOS Share menus feel immediate. Choosing
**Save to Tucked** should save one supported item to Tucked and dismiss without
asking for a collection or Favorite state.

This design replaces only the macOS confirmation experience described in
`2026-07-23-macos-share-extension-design.md`. The iPhone and iPad Share Sheet
keep the existing preview, Collection picker, Favorite toggle, Cancel, and Save
controls.

## Why This Is a Product Change

Live Safari verification confirmed that the macOS Collection picker works, but
it appears as a native menu inside Safari's ShareKit-owned system dialog. That
layered interaction is inherent to the current UI structure and is not guarded
by a Debug-only code path. A distribution build would therefore keep the same
awkward menu-within-a-share-surface experience.

Tucked already writes extension captures directly to the shared App Group
SwiftData store. The containing app does not need to launch or receive a
separate handoff, so removing the confirmation step does not require a new
service, URL scheme, or browser extension.

## Product Experience

On macOS:

1. The user chooses **Save to Tucked** from a standard Share menu.
2. Tucked loads and validates the shared URL, text link, or image.
3. The item is saved immediately with no collection and with Favorite off.
4. The Share request dismisses after the durable local write succeeds.

The system may show a brief **Saving to Tucked…** progress panel while the host
provides the item or SwiftData completes the write. The panel contains no
Collection picker, Favorite toggle, or confirmation button.

If the input is unsupported or the durable write fails, the panel stays open
and shows the existing useful error message with Retry and Cancel actions.
Tucked must never dismiss as though capture succeeded when the local write
failed.

On iOS and iPadOS, the current full confirmation form remains unchanged.

## Architecture and Data Flow

The existing multiplatform Share extension remains one target. No bundle
identifier, entitlement, App Group, CloudKit container, or activation-rule
change is required.

`ShareCaptureModel` gains one testable quick-save operation:

1. load providers through the existing deterministic URL, text-link, then
   image precedence;
2. stop and retain the failure state when no supported item loads;
3. save a valid capture through the existing save action with
   `collectionID: nil` and `favorite: false`; and
4. invoke the existing completion callback only after the repository-backed
   local save succeeds.

The macOS `ShareViewController` hosts a small quick-save view that starts this
operation once, reflects loading/saving/failure state, and exposes Retry and
Cancel only after failure. The iOS controller continues to host
`ShareCaptureView`.

The repository remains the only persistence owner. Link normalization,
existing-record update, recently-deleted restore, image downsampling, and
duplicate semantics do not change.

## Metadata

Quick Save does not wait for webpage metadata. A link is durable as soon as its
normalized URL is saved; metadata is optional derived data and may be enriched
later by the containing app. Image data remains validated and downsampled
before its local save because the image itself is source data, not metadata.

## Failure and Retry Behavior

- Unsupported or unreadable input reports that a web link or image is needed.
- Failure to open the shared store uses the existing storage Retry/Cancel
  screen.
- Repository save failure reports that the item was not saved and offers Retry
  and Cancel.
- Retry repeats the quick-save operation using the same providers.
- Cancel ends the extension request with the existing user-cancelled error.
- Completion is never called for load or save failure.

## Testing and Verification

Automated tests will verify:

- quick save uses no collection and Favorite off;
- quick save completes only after persistence;
- unsupported input does not call completion;
- save failure does not call completion and remains retryable;
- existing-link update and recently-deleted restore still use repository
  semantics; and
- the existing iOS confirmation-path tests continue to pass.

Live macOS verification will invoke **Save to Tucked** from Safari with the
containing app closed, confirm that no Collection menu appears, and confirm the
saved item is visible in All Items with no collection and Favorite off.

The signed macOS build, native macOS unit tests, and the focused iOS Share
capture tests will be rerun. This change does not provide new CloudKit
production-readiness evidence.

## Documentation Impact

Implementation will update `README.md`, `CHANGELOG.md`, and `DECISIONS.md` to
distinguish macOS Quick Save from the interactive iOS Share Sheet. `TODO.md`
needs no change unless implementation reveals new deferred work.

## Out of Scope

- opening the containing app after capture;
- remembering or configuring a default collection or Favorite state;
- a preference to switch between Quick Save and Ask Every Time;
- a second Share extension action;
- browser extensions or background services;
- changing the iOS or iPadOS Share Sheet;
- changing supported input types or multiple-item behavior; and
- changing identifiers, signing, entitlements, or CloudKit behavior.
