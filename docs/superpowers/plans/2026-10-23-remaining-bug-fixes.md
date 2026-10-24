# Tucked Remaining Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for task execution under `full-send`. Steps use checkbox syntax. Do not begin implementation until Geoff approves this spec and plan and hands over execution.

**Goal:** Complete the existing bug block and deliver tested local commits for physical-device acceptance.
**Architecture:** Preserve repository-owned mutations and the shared capture model. Add explicit Share intent where defaults currently overwrite saved values. Reuse existing viewers, native sharing, and SwiftUI layouts.
**Tech Stack:** Swift 6, SwiftUI, SwiftData, StoreKit 2, XCTest, system Apple frameworks.
**Spec:** [Tucked remaining bug fixes](../specs/2026-10-23-remaining-bug-fixes-design.md). Its behavior and exclusions control every task.

## Global Constraints

- Support iOS/iPadOS 18 and macOS 15. Use Swift 6 and system frameworks only.
- Work stays on `fix/mac-save-to-tucked`; inspect current HEAD and preserve unrelated changes. Planning baseline is `54ed538`; TestFlight 1.0 (9) app source is `f34b8c6`.
- Preserve the ten-item cap, lifetime ownership, Beta bypass, normalized identity, local durability, and current CloudKit schema.
- Use only iPhone 18 Pro (iOS 27.0). Resolve its UDID and pass it explicitly on every simulator operation. Do not use an iPad simulator.
- Do not reset live stores, alter real purchase history, install over TestFlight, push, merge, upload, submit, or change external trackers.
- Keep generated evidence in `.superpowers/sdd/2026-10-23-remaining-bug-fixes/`. Restore preferences and remove only this run's temporary app/extension registrations.

## Review Focus

- Untouched Share controls must preserve existing values; explicit None/off must still clear them (Task 2).
- A late metadata result must not erase user data or mark missing enrichment complete (Task 2).
- Opening Tucked from a rejected Share must not report a saved item or open an unrelated build (Task 3).
- Missing image bytes, invalid snippet sources, and stale selection must not crash or share another item (Task 4).
- Configuration cleanup must not disable Release gates or mix local StoreKit with real purchase evidence (Tasks 1 and 5).

## Task 1: Establish the baseline and default test configuration

**Files:** `BookmarkCollections.xcodeproj/project.pbxproj`; existing audit schemes; read-only `BookmarkCollections/Domain/BookmarkLimit.swift` and the verification matrix.
**Interfaces:** Preserve `PaywallConfiguration.isEnabled`, SKU, and scheme behavior. No production API change.

- [ ] Read project instructions and the spec. Inventory current branch, source state, machine/OS/Xcode, simulator UDID, user changes, installed apps, and extension registrations. Do not reset a dirty tree.
- [ ] Inspect Debug/Release/Beta effective settings for app, extension, unit tests, and UI tests. Set explicit extension paywall values and test floors per B5. Leave unrelated project settings alone.
- [ ] Confirm Debug/Release gates on and Beta gates off in effective build output. Run the existing focused gate/import tests on native Mac and the allowed iPhone without deployment overrides. Preserve logs and result bundles.
- [ ] Check available device results for B2. If physical evidence is absent, record the gate and continue local work. Do not infer a repair from a historical error string.
- [ ] Review and locally commit this bounded configuration correction after relevant checks pass.

## Task 2: Preserve re-shared data and durable capture

**Files:** `BookmarkShareExtension/ShareCaptureModel.swift`, `BookmarkShareExtension/ShareCaptureView.swift`, `BookmarkCollections/Domain/BookmarkRepository.swift`; tests in `BookmarkCollectionsTests/ShareCaptureModelTests.swift` and `BookmarkRepositoryTests.swift`.
**Interfaces:** Preserve existing repository callers' `save(url:collection:favorite:)` behavior. Use a narrow explicit Share intent or Share-specific repository entry point. Keep capture lookup and persistence in the model/repository, not view-local SwiftData edits. The exact helper signature is an engineer choice; record it before parallel delegation.

- [ ] Add failing tests: untouched active duplicate preserves UUID/date/title/organization/previews; interactive None/off applies; new normalized variant consumes no slot; deleted restore preserves fields and respects the cap; a new capture resets old form state.
- [ ] Add missing/late metadata and primary-save-failure regressions. Verify callbacks follow durable local success and enrichment remains independent of network timing. Include reload from a fresh ModelContext.
- [ ] Implement B1 with the smallest change. Do not broaden generic editor/import semantics. Keep valid local saves successful when optional metadata fails.
- [ ] Re-run repository, Share, metadata, deletion, import, and mixed-item cap tests on both platforms. Exercise duplicate re-share in a running local app/extension where tooling permits; record physical gaps.
- [ ] If B2 now has a reproducible our-code cause, add its regression and repair it here. Otherwise preserve the diagnosis status. Do not make speculative store/signing changes.
- [ ] Review and locally commit the capture correction after relevant checks pass.

## Task 3: Repair accessible layouts and Mac Share recovery

**Files:** `BookmarkCollections/Features/Bookmark/BookmarkEditorView.swift`; demonstrated failures only in `Features/Library/`, `Features/Collections/`, `Features/Settings/`, `Features/Paywall/`, and other editor views. `BookmarkShareExtension/MacQuickSaveView.swift`, `ShareViewController.swift`, and `ShareCaptureModel.swift`. Extract `BookmarkShareExtension/MacShareFailureView.swift` as a move-only step before behavior changes.
**Interfaces:** Keep existing save/completion behavior. Model failures must expose a typed reason for free-limit versus storage/unsupported failures. Do not branch on localized strings. The controller supplies an injectable Mac containing-app opener and the existing cancellation callback.

- [ ] Reproduce layout failures in the running iPhone app at accessibility5 with long content. Capture before/after. Apply the link editor's minimum width only on Mac. Preserve card style and the grid relayout workaround.
- [ ] Add focused UI checks for readable/reachable changed controls. Check light/dark, empty/populated states, editor Save/Cancel, scrolling, and navigation at the largest text size. Do not test every unchanged visual element.
- [ ] Implement B3's Mac free-limit Open Tucked/Cancel behavior. Recoverable storage failures keep Retry. Test opening success, opening failure, cancellation, no save callback, and storage Retry recovery using disposable/injected failures.
- [ ] Inspect the actual Mac failure surfaces at supported system text settings and with long content. Keep buttons reachable. Do not force a real shared-store failure by damaging the installed library.
- [ ] Record physical iPad layout/live-resize and inaccessible host-extension checks as pending, with exact steps. Review and locally commit verified layout/recovery changes.

## Task 4: Correct Mac sharing and verify existing Open routing

**Files:** Extract `BookmarkCollections/Features/Bookmark/ShareBookmarkSheet.swift` from `Features/Library/LibraryRootView.swift`; touch `Commands/BookmarkCommands.swift` and `Features/Bookmark/BookmarkActions.swift` only as needed. Add focused command/share tests in the existing test folders.
**Interfaces:** Preserve existing Open routing and `BookmarkCommandActions` unless a demonstrated defect needs a narrow capability flag. Use URL, image, or text ShareLink payloads per B4. No new sharing service or dependency.

- [ ] Extract the Share sheet without behavior changes. Verify existing image Open reaches ImageViewerView and marks opened; snippet Open reaches its editor. Do not rewrite already correct routing.
- [ ] Add regressions for image payload sharing, snippet body plus optional valid source, invalid source with usable body, missing/corrupt image, stale/absent selection, and sheet Cancel.
- [ ] Implement kind-aware Share. Use native controls, local saved content, and useful failure text. Keep URL sharing unchanged. Preserve Recently Deleted rules.
- [ ] Run the native Mac UI and focused payload tests. Inspect each changed Share screen in the running app. Update stale bug entries only when the evidence supports it.
- [ ] Review and locally commit the command correction after relevant checks pass.

## Task 5: Integrated verification, review, and handoff

**Files:** Applicable regression tests; this plan; `CHANGELOG.md`, `DECISIONS.md`, `TODO.md`, and `docs/verification/cloudkit-device-matrix.md`.
**Interfaces:** Preserve the completed Storefront/JSON APIs and all existing acceptance rules. Do not treat older build 9 results as tests of this changed package.

- [ ] Use a build-runner for required Xcode verification and a fresh code-reviewer for the completed diff, as required by full-send. Give any implementation delegate bounded ownership and tell them to preserve others' changes. Native sequential implementation is the default; delegation is not required for activity alone.
- [ ] Run complete unit and UI targets separately on native Mac and the allowed iPhone. Use `Tucked Audit` for isolated StoreKit cases as configured. Require default deployment settings, no unexpected skips, and readable xcresult summaries. Re-run the five prepared JSON fixtures through the actual importer.
- [ ] Build signed Release app/extension for generic iOS and native Mac using Tucked Release. Inspect versions, identifiers, paywall settings, and signing entitlements. Local Release signatures do not prove Production distribution.
- [ ] Resolve actionable review findings and repeat affected checks. Preserve an exact tested-state fingerprint; tie final evidence to the local commit. Record failed/tooling-blocked checks accurately.
- [ ] Restore test preferences and registrations. Review the complete diff and `git diff --check`. Update project docs with delivered behavior and separate pending physical-device gates. Keep the spec draft/implementation/device status accurate; do not archive it.
- [ ] Commit scoped work and inspect the final commit/status. Stop at **Ready for Geoff's device testing**, or **Blocked** if required local checks cannot pass. Report passes, failures, blocked checks, evidence location, physical steps, and unchanged push/release/merge status.

## Execution record

- Drafted 2026-10-23 at `54ed538`. No implementation started. No device gate closed by planning.
- Fresh read-only builder check: no material questions remained.
- Approval and full-send execution handoff: pending.
- Record actual execution commits, checks, blockers, and next action here when execution starts.
