# Tucked remaining bug fixes

**Status:** Approved for local implementation on 2026-10-24. Device acceptance and release actions remain separate gates.
**Execution:** Use `full-send` after approval, with the [implementation plan](../plans/2026-10-23-remaining-bug-fixes.md). One explicit approval and handoff can authorize both documents; do not add another routine approval gate during execution.
**Baseline:** `fix/mac-save-to-tucked`, inspected at `54ed538`. App fixes in `f34b8c6` shipped to internal TestFlight as 1.0 (9). Later fixes require new verification and separately authorized uploads.

## Intent and boundary

Finish the remaining bug block without adding the next feature chapter. Preserve saved organization when a link is shared again. Correct existing Mac actions, accessible layouts, and build settings. Investigate the reported iPhone Share storage failure from evidence. Preserve the completed paywall and JSON corrections.

This spec proposes the behavior below. It does not claim Geoff has approved these choices yet. Ordinary implementation details remain with the engineer.

- Support iOS/iPadOS 18 and macOS 15. Use Swift 6 and system frameworks only.
- Keep the ten-active-item combined cap, lifetime SKU, Beta bypass, bundle identifiers, App Group, and CloudKit container.
- Preserve local-first durability, normalized URL identity, canonical UUID selection, deletion/restore rules, and existing backup formats.
- Keep the existing card style and width-bucketed iPad grid relayout workaround.
- Use only iPhone 18 Pro (iOS 27.0) for simulator interaction. Resolve and pass its exact UDID each time. Physical iPad checks remain device gates.
- Preserve live libraries, purchase state, user preferences, and installed TestFlight app/extension registration. Do not reset stores or purchase history, replace installed apps, or change CloudKit schemas without separate authorization.

Exclude highlighted-text capture, menu-bar helpers, new import paths, image-capable backups, visual redesign, and general refactoring. Do not push, merge, archive/upload new release builds, submit to either review process, or change external trackers under this package.

## Required behavior

### B1. Re-sharing preserves existing user data

A normalized URL already saved must retain its UUID, created date, edited title, collection, Favorite state, and usable preview/favicon unless the user explicitly changes an editable value. Re-sharing adds no active item and remains allowed at or above ten.

- **Mac Quick Save:** Preserve existing title and organization. For a new link, keep no collection and Favorite off.
- **iPhone/iPad interactive Share:** Load the matching record's collection and Favorite into the controls. An untouched form preserves them. An explicit choice of None or Favorite off must still apply. Switching to a different capture must not reuse the previous capture's state.
- Keep existing nonempty titles and image data. Incoming metadata may fill missing fields. Missing incoming values must not erase existing fields. A provider's suggested name alone must not mark an unenriched link ready. A metadata-less new Quick Save remains eligible for enrichment.
- Use repository mutations. Do not change generic import or editor behavior to fix Share defaults. Primary persistence failure must not call completion. Metadata failure must not invalidate a durable URL save or delay capture until a network request finishes.
- Re-sharing a deleted link still restores the existing record and consumes capacity. Preserve its data using the same platform rules. Reject restoration at ten without changing the record.

### B2. Diagnose the physical iPhone Share storage failure

The reported message is “Tucked could not open its shared library.” Simulator Share now passes; a current physical-device failure is not yet established.

Use build 9 device results and `ShareStorage` / `ShareSave` logs to identify whether failure occurs while opening the shared store or saving. Record device, OS, build, host app, exact error domain/code chain, and app/extension entitlements. If reproduced in our code, make the smallest evidence-backed repair and add a deterministic regression. Keep storage failure separate from a free-limit refusal or unsupported text.

Do not invent a schema migration, recreate a store, disable CloudKit, or change signing identifiers as a speculative cure. If device access or logs are absent, complete independent local work and leave this as an explicit physical-device gate. Do not mark the reported defect fixed from simulator evidence.

### B3. Accessible layouts and Mac failure recovery

Check the populated grid, sidebar, link editor, snippet editor, Settings/paywall, and Share failure screens. Use long titles, long domains/URLs, and collection names at the largest iOS accessibility text size. Essential labels and actions must remain readable and reachable without horizontal clipping or stacked word fragments. Scrolling and intentional image/card-title previews may remain; expose full item details accessibly.

Apply the link editor's desktop minimum width only on Mac. Repair demonstrated layout failures with native layout and semantic fonts. Do not reduce text size or redesign the card system to make checks pass.

On Mac, verify free-limit, unsupported-input, and storage-failure screens in light/dark appearance and the largest supported system text size. Injected text-size stress may supplement a real capture; it does not establish system support. Let the failure surface size or scroll to keep its message and buttons reachable. Do not retain a fixed 360 x 200 limit if it clips content.

For the **Mac free-limit failure only**, replace Retry with **Open Tucked**, alongside Cancel. Identify the failure by type, not localized message text. Open the containing installed app through supported macOS APIs. Do not add a URL scheme or an iOS extension-launch workaround. Successful opening ends the unsaved Share request as cancellation, not save completion; the user must share again after resolving the limit. If opening fails, retain the error surface and Cancel. Keep Retry for recoverable storage/save errors. iOS keeps its existing Share flow and clear blocked-save feedback.

### B4. Mac commands use the selected item's kind

Current code already routes Open to the image viewer, snippet editor, or link URL. Verify that behavior before changing it; retire the stale image-Open TODO if it passes.

| Item | Open | Share |
| --- | --- | --- |
| Link | Open its HTTP/HTTPS URL | Share that URL |
| Image | Open the existing image viewer | Share the stored image through native sharing |
| Snippet | Open the existing snippet editor | Share its body as text; append a valid source URL on a separate line if present |

A missing or undecodable image must show a useful image error, not an invalid-URL message. An invalid snippet source must not prevent sharing its body. Preserve Cancel in the Share sheet. Disable selected-item commands when selection is absent or stale after filtering/deletion. Preserve existing Recently Deleted rules and link behavior.

Extract the substantive Share sheet into its own file before changing it. Reuse existing image decoding/native ShareLink behavior. Do not create a second sharing subsystem or require network access to share saved content.

### B5. Explicit configuration and reliable default tests

Set `PAYWALL_ENABLED` explicitly for the extension in every configuration: YES for Debug/Release and NO for Beta, matching the app. Verify effective values rather than only editing the project text. No Release product may bypass the cap.

Set both unit and UI test targets to iOS 18 and macOS 15 in all supported configurations. Default Mac and the allowed iPhone test commands must work without deployment-target overrides. Keep the signed Mac UI runner and local StoreKit audit isolation.

## Acceptance and evidence

| Gate | Required evidence |
| --- | --- |
| B1 | Unit regressions for active/deleted duplicates, normalized variants, explicit None/off, metadata absence, persistence failure, reload, and capacity; live Share re-save on each available platform |
| B2 | Deterministic storage success/failure/retry checks; original physical-device result and logs, or clearly pending physical acceptance |
| B3 | Running-app captures and interactions in light/dark and largest text; Mac failure actions and failed-open recovery; physical iPad narrow/wide and live-resize checks remain pending if unavailable |
| B4 | Native Mac menu tests for all three kinds, missing image, invalid source, stale selection, and Cancel; image Open may need evidence only |
| B5 | Effective configuration inspection, default unit/UI runs on Mac and iPhone, signed Release builds for both platforms |
| Regression | Existing paywall, local StoreKit lifecycle, mixed-item cap, JSON fixtures, and backup tests pass on the final code state; independent review has no unresolved actionable finding |

Record results and screenshots under `.superpowers/sdd/2026-10-23-remaining-bug-fixes/`. Use the plan as the execution ledger. Keep device/account acceptance in `docs/verification/cloudkit-device-matrix.md`; do not overwrite historical evidence.

Full-send ends with tested local commits, restored test state, and a report of passes, failures, and blocked checks. Required local verification or review failure blocks that handoff. Identified physical-device gates may remain pending, with exact instructions. Production purchase/restore, immediate Mac unlock, cross-platform ownership, physical Share, fresh-account Production sync, and offline conflicts still gate submission. Build 9 results do not prove later changed code. Upload and eventual merge need separate approval.
