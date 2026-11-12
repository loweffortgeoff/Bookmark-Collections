# Tucked branch and paywall audit — 2026-10-23

## Recommendation

**Hold App Store submission pending the remaining device and account checks.** The approved code corrections and final validation are recorded in the follow-up below. The initial audit changed only tests and documentation. No real purchase, upload, merge, or push occurred.

## Scope and environment

- Branch: `fix/mac-save-to-tucked`, starting at `17186ac`. The checkout was clean.
- Machine: Geoffrey’s Mac mini, macOS 27.0.1 (26A434), Xcode 27.1 (27A9275).
- Simulator: iPhone 18 Pro, iOS 27.0, `A529490C-F919-4603-A516-FB3ECEDB09B1`. No other simulator was used.
- Unit stores and UI fixtures used disposable in-memory data. The live Mac Share limit attempt did not save a test bookmark. Local StoreKit transactions were simulated, not real purchases.
- Test targets inherit deployment versions below the app minimum. Unmodified baseline test commands fail to compile: macOS 14 vs 15, iOS 17 vs 18. Tests below use command-line overrides, not project edits.

## Initial audit results

| Check | Result | Evidence |
| --- | --- | --- |
| Original Mac unit suite | 110 pass | `mac-unit-override.xcresult` |
| Expanded Mac domain/unit suite | 128 pass, 3 fail; 10 StoreKit cases skipped in this run | `mac-final-unit.xcresult` |
| Expanded iPhone domain/unit suite | 128 pass, 3 fail; StoreKit tested separately | `ios-final-unit.xcresult` |
| Existing Mac UI cases | 11 pass | `mac-ui-full.xcresult`; three new probes failed separately |
| Existing iPhone UI cases | 11 pass | `ios-ui.xcresult`; initial new-probe locator failures were corrected |
| New iPhone paywall/export UI cases | 3 pass | `ios-paywall-ui-final.xcresult` |
| iPhone local StoreKit lifecycle | 9 pass, 2 fail | `ios-storekit-final.xcresult` |
| Mac local StoreKit lifecycle | 5 pass, 6 fail | `mac-storekit-final.xcresult`; isolated purchase failure also repeats |
| Signed Release builds, Mac and generic iOS | Both pass | `mac-release.log`, `ios-release.log` |
| Mac Beta build and bypass flags | Pass | `mac-beta.log`; app and extension both resolve `PaywallEnabled = NO` |
| Live Mac Safari free-limit card | Pass, light and dark appearance | Visible message, Cancel and Retry; `mac-share-live.log` records 360 × 200 frame and limit refusal; `mac-share-light.log` covers light mode |
| New Mac paywall UI probes | Automation failure, 3 cases | XCTest sees a disabled app with a menu bar and no window. Live manual Add Link → paywall → Close works. |

Evidence files are under `/tmp/tucked-audit-20261023/`. Pass/fail counts count test cases, not repeated assertion messages. The StoreKit test class now has 11 cases; the earlier ordinary Mac unit run skipped the 10 that existed at that time.

## Confirmed findings

### 1. Paid owners can remain locked when product loading fails — submission blocker

**Side: our app code.** `Storefront.load()` requests the product before it refreshes entitlements. If that request throws, it only sets an error message. A verified owner with no cached unlock flag remains locked.

The controlled test first confirms that StoreKit exposes a verified lifetime entitlement. It then clears the local unlock cache and simulates a product-catalog error. The new Storefront stays locked. This repeats on iPhone and Mac.

- Source: `BookmarkCollections/Domain/Storefront.swift:29`.
- Test: `StorefrontAuditTests.testProductLoadFailureKeepsExistingVerifiedPurchaseAccessible`.
- Evidence: `ios-storekit-final.xcresult`, `mac-storekit-final.xcresult`.

### 2. Mac local purchase succeeds but does not unlock the active Storefront — submission blocker until resolved

**Side: app/StoreKit integration; production cause is not isolated.** An isolated local purchase creates one transaction. `Transaction.latest(for:)` returns a verified Xcode-environment non-consumable. `Storefront.errorMessage` is nil. Both the active Storefront and shared unlock flag remain false during the five-second check.

Creating a new Storefront then unlocks it and the shared flag, while the original Storefront remains locked. The same purchase test passes on iPhone. Mac pending approval and restore also fail to unlock. The refund and successful-purchase feedback cases cannot establish their initial unlocked state; these are not six independent defects. Do not describe these as real App Store payment failures. They establish a local Mac integration failure that needs a fix or independent current-build sandbox/TestFlight evidence.

- Source boundary: `BookmarkCollections/Domain/Storefront.swift:44` and `:81`.
- Test: `StorefrontAuditTests.testPurchaseUnlocksSharedAccessAndNewStorefront`.
- Evidence: `mac-purchase-diagnostic.log`, `mac-purchase-recheck.log`, `mac-storekit-final.xcresult`.

### 3. A rejected JSON import changes collections — submission blocker

**Side: our app code.** JSON import inserts or updates collections before checking the free limit. A rejected import leaves one imported collection and `ModelContext.hasChanges == true`. A later save or autosave can retain those changes even though the operation reported failure.

- Source: `BookmarkCollections/Domain/LibraryImportService.swift:74`; gate at `:96`.
- Test: `PaywallImportAuditTests.testRejectedJSONImportLeavesNoCollectionsOrPendingChanges`.
- Evidence: identical failure in Mac and iPhone expanded unit runs.

### 4. JSON import overcounts duplicate-only updates — confirmed gate defect

**Side: our app code.** At ten active links, a JSON record with the same normalized URL but a different UUID is rejected even though reconciliation would leave ten. A same-ID backup of a library already above ten is also rejected, although it adds no active items. Duplicate-only text import succeeds in the same conditions.

- Source: `BookmarkCollections/Domain/LibraryImportService.swift:211`.
- Tests: `testJSONDuplicateURLAtLimitDoesNotRequireAnotherSlot`, `testExistingBackupCanUpdateLibraryAboveLimit`.
- Evidence: identical failures in Mac and iPhone expanded unit runs.

### 5. Successful purchase retains an earlier restore error — confirmed purchase feedback defect

**Side: our app code.** Restore on a fresh account sets “No Tucked for Life purchase was found for this Apple Account.” A subsequent successful purchase unlocks the iPhone Storefront, but that message remains. Success does not clear `errorMessage`.

- Source: `BookmarkCollections/Domain/Storefront.swift:44` and `:67`.
- Test: `StorefrontAuditTests.testSuccessfulPurchaseClearsEarlierRestoreError`.
- Evidence: `ios-storekit-final.xcresult`. Mac does not get past the earlier unlock failure in this case.

## What works

- Links, images, and snippets share one ten-active-item cap. Unlocked and Beta repositories accept additional items.
- Deletion frees one slot. Restoring below the cap uses that slot. Restore and re-save of deleted links are blocked at the cap without activating the item.
- Existing links and snippets remain editable above the cap. Favorite, open tracking, HTML export, and JSON export remain available.
- Image and text batches stop at ten without creating an eleventh item. An accepted prefix of a batch remains saved if a later item reaches the cap; the operation then reports the limit rather than a partial-import summary.
- A blocked Share save neither inserts a bookmark nor calls completion. Re-sharing an existing link at the cap still completes.
- iPhone local StoreKit covers fresh locked state, purchase, a new Storefront reading the purchase, cancellation, failed purchase, pending approval, refund revocation, restore with a purchase, and restore without one.
- Navigation, Favorites/organization accessibility values, context-menu editor/info, image/snippet filtering, bulk-action visibility, deletion confirmations, and Settings pass the existing Mac and iPhone UI cases.
- iPhone link and snippet saves reach the paywall at a forced limit. Close dismisses it. Locked JSON export opens the native Files exporter.
- Live iPhone paywall light/dark layouts are readable. At accessibility5, scrolling reaches Unlock and Restore. The large navigation title truncates to “Tucked for L…” at the top; the inline title is complete after scrolling. This is a visual issue, not a demonstrated gate failure.
- Live Mac Safari now shows the free-limit failure card. Retry keeps the error visible. Cancel dismisses it. The background and controls are readable in light and dark appearance. Largest Mac text and a live storage-failure screen remain unverified; neither was forced by altering the real library. Live Mac in-memory Add Link also opens and dismisses the paywall.

## Build and release boundaries

Release app bundles contain `PaywallEnabled = YES`. Release extension bundles contain an empty string because the extension Release build setting is absent. `PaywallConfiguration.isEnabled` treats that value as enabled. The effective release gate is on for both targets. Beta bundles contain `NO` for both targets. The audit did not alter these settings.

The signed Mac app and extension carry the same App Group and CloudKit container, the expected team, sandbox access, and outgoing network permission. A signed build does not prove Production CloudKit or App Store purchase behavior.

The earlier real-device iOS Share storage failure remains open until reproduced and retested on that device. Simulator findings will be recorded below. Fresh-account Production sync, offline conflict checks, current-build TestFlight purchase/restore on both platforms, and cross-device purchase access remain release evidence gaps. Existing historical device results are not fresh branch validation.

No App Store Connect state, IAP review status, build attachment, or submission status was changed or independently verified in this audit. No upload or submission occurred.

## Tooling notes

- Mac UI startup initially timed out while enabling automation mode. Geoff completed the macOS prompts. All eleven existing cases then passed. Developer mode remains disabled; the audit did not change that system setting.
- Three new Mac paywall probes still see only a menu bar under XCTest. Live CUA interaction with the same built app and in-memory arguments works. Keep this automation gap separate from an app failure.
- Initial iPhone paywall probes used incorrect field/picker locators. The corrected three-case rerun passes. The URL field uses the `https://example.com` placeholder; Files exposes Cancel in automation while Save is visible on screen.
- The simulator test tool's packaged-product route did not activate the StoreKit scheme configuration. Direct `xcodebuild test` with `Tucked Audit` did. An unexpected Apple Account sign-in prompt from the invalid setup was cancelled without credentials. Only configured local StoreKit runs support the lifecycle results above.
- One early iPhone result-finalization run stalled after test execution and logged SDK build parsing errors. The later eleven-case local StoreKit run produced a complete result bundle.
- Xcode device-interaction sessions were closed after use. One initial close timed out; the later cancellation session closed successfully.

## Reproduction

Run domain tests with `BookmarkCollections` and `-only-testing:BookmarkCollectionsTests`, excluding `StorefrontAuditTests`. Run purchase tests with `Tucked Audit` and `-only-testing:BookmarkCollectionsTests/StorefrontAuditTests`. Keep StoreKit cases serial. This scheme attaches the local configuration and supplies `-storekit-audit`; ordinary schemes skip these purchase tests to prevent accidental use of a real StoreKit environment.

**Owner Macs (added 2026-10-24).** Do not run the Mac StoreKit audit on a Mac with a TestFlight or App Store Tucked that holds a lifetime purchase. The test app then sees that Sandbox entitlement instead of the local session, and setup stops with "Local StoreKit history did not clear before the scenario." Run it on a Mac without that purchase, or rely on the iPhone simulator audit. Ordinary UI-test launches (`-ui-testing` without `-storekit-audit`) no longer query StoreKit, so the paywall UI tests run on any Mac.

Use `MACOSX_DEPLOYMENT_TARGET=15.0` for native Mac tests, or `IPHONEOS_DEPLOYMENT_TARGET=18.0` with `-destination 'platform=iOS Simulator,id=A529490C-F919-4603-A516-FB3ECEDB09B1'`. Both are temporary command-line overrides. [Apple documents the shared StoreKit test environment and serial execution requirement](https://developer.apple.com/documentation/storekittest/sktestsession).

## Live iPhone Share follow-up

The normal simulator durable store began empty. Safari → Save to Tucked saved a link, and Photos → Save to Tucked saved a disposable app-icon image. Both cards remain after app termination and relaunch. No storage error appeared. The time-filtered live-period log has no ShareStorage/ShareSave errors.

Evidence: `ios-normal-empty-library.png`, `ios-shared-link-after-relaunch.png`, `ios-share-image-form.png`, `ios-shared-image-after-relaunch.png`, and `ios-live-share-only-logs.txt` under the evidence directory. Broader logs include deliberate unit-test failures; those are not live Share failures.

This proves simulator local capture below the limit. It does not resolve the physical-device report or prove CloudKit sync. Two test items remain in the simulator; no real-device library was changed. Appearance/text size were restored to light/large.

## Test-state closeout

The original Mac dark appearance and original shared unlock flag (`true`) were restored and read back. Temporary Mac Share extension registrations were removed. `pluginkit` selects `/Applications/Tucked.app/Contents/PlugIns/BookmarkShareExtension.appex` again. No test app or test process remains running on the Mac. Simulator test items remain by design. Test/report changes remain uncommitted for review. No product or architecture decision changed, so DECISIONS.md is unchanged.


## Approved fix follow-up

Geoff approved the focused plan and full-send execution on 2026-10-23. Work remains on `fix/mac-save-to-tucked`. The fixes preserve the ten-active-item cap and existing import conflict rules.

### Delivered behavior

- Storefront checks verified lifetime ownership independently of product loading. Purchase and transaction updates deliver access before finishing; startup and restore read the latest verified lifetime transaction and check revocation. An earlier suspended ownership lookup cannot overwrite a newer verified update.
- Purchase, approval, and restore clear obsolete errors and dismiss the paywall when access unlocks. Failed operations retain current feedback. Refunded history cannot unlock a fresh instance, even with a stale true cache.
- JSON import preflights valid records before changing collections or bookmarks. Both the existing and projected counts use canonical reconciliation. Duplicate-only updates above ten work; genuine growth over ten is rejected without changing imported data or unrelated pending edits.

### Mac purchase cause

The isolated trace shows a verified non-consumable purchase immediately available through the purchase result and `latest(for:)`, while `currentEntitlements` still returns an empty sequence. Our code treated that empty sequence as a final ownership decision and did not check again. A controlled poll observed the projection become populated after **0.734 seconds**; reloading the same original Storefront then unlocked it. New-object creation was not the cure: it happened later and performed another read.

The correction grants access from the verified purchase itself and uses the latest verified transaction for this single lifetime SKU. It adds no production delay or forced preference override. This resolves the reproduced local Mac integration failure; it does not establish App Store sandbox or TestFlight behavior.

### Final automated evidence

Evidence is in the ignored `.superpowers/sdd/2026-10-23-paywall-json-fixes/` directory. Same machine and simulator as the initial audit.

| Check | Result | Evidence |
| --- | --- | --- |
| Mac complete unit, local StoreKit, and UI package | **169 pass, zero failures/skips** (154 unit + 15 UI) | `mac-complete-package.xcresult` |
| iPhone complete unit, local StoreKit, and UI package | **169 pass, zero failures/skips** (154 unit + 15 UI) | `verification/ios-all-final.xcresult` |
| Local StoreKit scenarios, included above | 13 per platform | Purchase, approval, refund, fresh revoked owner, restore, catalog failure with/without ownership, and stale feedback |
| JSON import regressions, included above | 17 per platform | Sync duplicates, ID collisions, malformed input, canonical deletion, mixed kinds, and pending-edit preservation |
| Native purchase UI, included above | Pass on both platforms | Restore failure → local purchase → automatic paywall dismissal → same-instance unlocked Settings; local session confirms one transaction |
| Signed Mac and generic iOS Release builds | Both pass | `verification/mac-release-final-v3.log`, `verification/ios-release-final-v3.log` |
| Independent code review | Accepted after repairs | Reconciled baseline, audit-only purchase guard, and transaction-assertion timing corrected; final production and UI delta has no remaining actionable finding |

**No remaining failures in the final package runs.** Earlier red regressions and incorrect UI locators remain in the diagnostic evidence. The Mac menu-only automation gap is resolved by test setup. Native export verifies the enabled Export control in the `save-panel` sheet and cancels without writing a file.

A further native capture showed that access unlocked while the paywall still offered Unlock. The iPhone purchase UI regression reproduced this before the fix. `PaywallView` now dismisses when Storefront becomes unlocked. This includes purchase, restore, and approval, with no change to the ten-item policy or pending-save behavior. Purchase UI proves the active Storefront and visible flow; unit StoreKit and repository tests establish shared access and creation above the cap.

Final relevant-source fingerprint: `184c56ab2d2e9a348722cd8149a84cc536ec4a8aa286fc5290e3a2fab4fbc64f`. Per-file hashes are in `tested-inputs.sha256`. Result summaries were read back from the complete result bundles. The local commit is the handoff state; no push or release action is authorized here.

### Test harness corrections and limits

- The local StoreKit server can return from transaction reset or purchase before the client's history/projection catches up. Scenario setup waits for cleared history; the refund simulation waits for a visible purchased entitlement before requesting a refund. The app purchase regression still requires immediate unlock without waiting for that projection.
- A new cancellation-after-restore probe expected nil feedback from simulated `.userCancelled`. Instrumentation proved this SDK returned `StoreKitError.unknown` instead. The app correctly displayed that current failure. The invalid nil assertion was replaced with successful-restore error clearing; the existing cancellation-error/no-unlock case remains. Actual purchase-sheet cancellation still needs the current-build sandbox/device check.
- Native Mac XCTest launched with numeric `-free-limit` values showed no initial window. Launching with only `-ui-testing` restores the window. The Mac gate probes now fill the seeded library from seven to the real ten-item cap through successful UI saves. This changes test setup, not product behavior.
- The native Mac toolbar and File menu both expose Add Link. Gate probes use Command-N/Command-T for the existing commands to avoid an ambiguous menu query. The save panel is a sheet named `save-panel`, with an Export button (`OKButton`), rather than a dialog or Save button.

### Remaining submission gates

The initial physical-device Share storage failure remains unresolved by simulator evidence. Verify links and images on that device, including persistence after relaunch and offline capture. Verify current-build purchase/restore on iPhone and Mac through sandbox/TestFlight and cross-device lifetime access. Complete fresh-account Production CloudKit sync, offline/conflict checks, and final human device/accessibility checks in `cloudkit-device-matrix.md`. Historical schema deployment and uploads are not current-build acceptance evidence.

Test-target deployment settings still require the documented command-line overrides. No project build setting, App Store Connect record, or release state was changed by these fixes. `DECISIONS.md` records the verified-transaction boundary. The approved cap and purchase policy are unchanged.


### Final test-state closeout

The Mac's original shared unlock flag (`true`) and dark appearance were restored/read back. This plan's temporary Mac app and extension registrations were removed. `pluginkit -m -v` selects `/Applications/Tucked.app/Contents/PlugIns/BookmarkShareExtension.appex`. No test app or runner remains active on Mac. Only disposable in-memory libraries and local StoreKit transactions were used in this implementation pass. The two normal simulator test items from the initial audit remain; no real library was reset.

Final status: **Ready for Geoff's device testing. Hold submission for the gates above.** No remaining failed or skipped checks in the final package runs. No real payment, push, merge, upload, or submission occurred.
