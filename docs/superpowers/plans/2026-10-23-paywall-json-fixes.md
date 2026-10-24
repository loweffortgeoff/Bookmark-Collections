# Paywall and JSON Import Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans after Geoff approves this plan. Track the steps below. Implement in this session.

**Goal:** Fix the confirmed ownership, purchase feedback, and JSON import gate defects, and identify why a successful Mac purchase leaves the active Storefront locked.

**Architecture:** Keep ownership handling in `Storefront` and JSON import handling in `LibraryImportService`. Check verified ownership independently of product availability. Validate the effective JSON changes before mutating SwiftData, using the existing URL identity and duplicate reconciliation rules.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, StoreKit 2, StoreKitTest, XCTest.

**Spec:** The confirmed findings in [the branch audit](../../verification/2026-10-23-branch-paywall-audit.md), plus Geoff's request to fix them and retain the Mac purchase investigation.

## Global Constraints

- Work on `fix/mac-save-to-tucked`. Preserve the existing audit changes.
- Wait for plan approval before editing app code or running implementation experiments.
- Keep the ten-active-item free cap, verified lifetime purchase, and Beta bypass.
- Support iOS/iPadOS 18 and macOS 15. Add no dependencies or new product features.
- Use only iPhone 18 Pro, iOS 27.0: `A529490C-F919-4603-A516-FB3ECEDB09B1`.
- Use simulated StoreKit transactions. Do not make real purchases, upload, submit, merge, or push.
- Preserve the Mac's original shared purchase flag and installed Share extension registration after tests.

## Review Focus

- Catalog failure must not lock a verified owner with an empty local cache.
- A late entitlement refresh must not overwrite a newer verified ownership result.
- Purchase approval, restore, and revocation must update the active Storefront and shared access consistently.
- JSON identity collisions, malformed records, and repeated URLs must not consume fictitious slots.
- A rejected JSON gate must preserve existing collections and unrelated pending user edits.

## Task 1: Resolve Storefront ownership and feedback

**Files:** `BookmarkCollections/Domain/Storefront.swift`; `BookmarkCollectionsTests/StorefrontAuditTests.swift`. Inspect `BookmarkLimit.swift` and the paywall view call sites; change them only if the reproduced cause requires it.

**Interfaces:** Preserve `load() async`, `purchase() async`, `restorePurchases() async`, and the observable state consumed by the paywall. `PurchaseAccess.setUnlocked(_:)` remains the shared access cache.

- [x] Re-run the isolated Mac purchase failure with the local StoreKit scheme. Trace purchase verification, transaction finishing, entitlement enumeration, and every ownership state write. Check overlapping startup/update tasks and test-session isolation. Record why the original Storefront stays false while a new one becomes true.
- [x] Keep the existing failing purchase and catalog tests. Add a focused regression for the demonstrated Mac cause, including overlapping refreshes if they contribute. Do not weaken assertions or add arbitrary delays to obtain a pass.
- [x] Make verified ownership checks independent of catalog success. Apply the smallest correction supported by the Mac trace. Keep product identity, verification, and revocation checks; update active state and shared access together.
- [x] Clear obsolete purchase/restore errors when a new operation begins and when ownership succeeds. Test restore-error → purchase success, pending → approval, restore success, and genuine failure feedback.
- [x] Run all eleven existing StoreKit lifecycle cases plus new regressions on Mac and iPhone. Confirm purchase unlocks the same instance, shared access, and a new instance. Confirm cancellation/failure do not unlock and refund revokes access.

**Acceptance:** The Mac failure has an evidence-backed explanation and regression coverage. Purchase, pending approval, restore, catalog failure, and stale feedback cases pass on both platforms. If the cause proves specific to the test harness, document that proof and validate the app integration independently; do not relabel an unexplained failure as tooling.

## Task 2: Correct JSON gate preflight

**Files:** `BookmarkCollections/Domain/LibraryImportService.swift`; `BookmarkCollectionsTests/PaywallImportAuditTests.swift`. Read `BookmarkRepository.swift` and `BackupDocument.swift` to preserve current identity and backup behavior.

**Interfaces:** Keep `importJSON(_ data: Data) throws -> ImportSummary`. Replace the private `assertCanImport` calculation as needed. Reuse `NormalizedURL` and existing duplicate reconciliation semantics.

- [x] Extend the three failing import regressions. Cover existing collection renames, unrelated pending edits, repeated imported URLs/IDs, invalid URLs, blank snippets, link/snippet ID collisions, and deleted-item restoration.
- [x] Calculate effective active growth from valid records and the resulting reconciled identities before inserting or editing collections or bookmarks. Include links, images, and snippets already in the library.
- [x] Permit duplicate-only and zero-growth updates at or above ten. Reject new/restored growth that exceeds ten. Preserve existing backup conflict rules and invalid-record reporting.
- [x] Ensure a limit rejection changes no imported data and leaves pre-existing pending edits intact. Avoid a broad context rollback that discards unrelated edits.
- [x] Run import, backup round-trip, repository, duplicate reconciliation, and mixed-item gate tests on Mac and iPhone.

**Acceptance:** An eleven-item growth import is rejected without mutation. Ten valid items succeed. Normalized duplicates at ten and same-library updates above ten succeed. Deleted-item restores still consume capacity. Existing data and unrelated edits survive rejection.

## Task 3: Verify the integrated fixes and report readiness

**Files:** Existing audit tests and scheme; `docs/verification/2026-10-23-branch-paywall-audit.md`; `CHANGELOG.md`; `TODO.md`. Update `DECISIONS.md` only if an approved decision changes.

- [x] Run serial StoreKit tests with direct `xcodebuild test`, scheme `Tucked Audit`, and `-only-testing:BookmarkCollectionsTests/StorefrontAuditTests`. Use `platform=macOS` with `MACOSX_DEPLOYMENT_TARGET=15.0`, then the specified iPhone UDID with `IPHONEOS_DEPLOYMENT_TARGET=18.0`. Require complete result bundles and zero unexpected failures.
- [x] Run the broader unit suite and existing UI suite on both platforms. Re-run the three iPhone paywall/export cases. Investigate the Mac menu-only automation gap without treating it as proof of an app defect; confirm the Mac purchase/paywall flow in the running app.
- [x] Recheck link/snippet gates, editing/export access, mixed-item capacity, and shared access used by the Share extension. Build signed Mac and generic iOS Release configurations.
- [x] Restore test state, review the complete diff, and run `git diff --check`. Update the audit with before/after evidence and exact remaining failures or blocked checks.
- [x] Report what passed, what failed, and what still blocks submission. Keep physical-device Share capture, Production CloudKit, and current-build sandbox/TestFlight purchase/restore evidence separate from local test passes.

**Completion boundary:** Finish these app fixes and their validation in this scope. App Store submission remains a separate decision. Do not claim production purchase or sync readiness from local StoreKit and simulator results.


## Execution record

- Approved full-send on 2026-10-23; branch `fix/mac-save-to-tucked`, starting commit `17186ac`. Preserve the initial audit work in the same package.
- Tasks 1 and 2 are implemented. Mac diagnosis and JSON regressions are recorded in the audit follow-up. Independent review accepted the fixes after correcting the reconciled baseline count and two UI-test issues.
- Related repair: a verified purchase unlocked access but left the paywall open. The iPhone purchase UI regression reproduced this. `PaywallView` now dismisses when the observed Storefront unlocks; the purchase UI test covers both platforms with a bundled local StoreKit fixture.
- Final package verification: Mac 169/169 and iPhone 169/169, zero failures/skips. Both signed Release builds pass. Independent review is clean. Evidence and detailed rulings are in `.superpowers/sdd/2026-10-23-paywall-json-fixes/`; the final input fingerprint is `184c56ab2d2e9a348722cd8149a84cc536ec4a8aa286fc5290e3a2fab4fbc64f`.
- Stop at a local commit ready for physical-device testing. Current-build sandbox/TestFlight purchase/restore, cross-device access, physical Share capture, and fresh-account Production sync remain external acceptance gates. Do not mark the overall release ready or archive this plan.

**Implementation status:** Complete locally; test state restored. Ready for Geoff’s device testing. The local handoff commit is identified by this file’s Git history and the execution ledger. Release acceptance remains pending the device/account gates above.

- Test-state closeout: original Mac shared unlock flag and dark appearance restored; temporary plan registrations removed; installed Share extension selected. No test process remains on Mac. No release or external tracker action occurred.
