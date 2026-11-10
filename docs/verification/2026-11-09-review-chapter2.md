# Review fixes, Chapter 2 — local verification

Source: `b9197be` on `fix/review-enrichment-purchase`; later changes are documentation only. Chapter 1 was merged locally to `main` at `411b8e8` with Geoff’s authorization. Chapter 2 is not merged or pushed.

Machine: Geoffrey’s Mac mini, macOS 27.2 (26B123), Xcode 27.2 (27B52). iPhone tests used only iPhone 18 Pro, iOS 27.0 (24A434), UUID `204520A6-E5B5-447D-8A6B-028317014DD8`.

## Automated checks

| Check | Cases, including skips | Skipped | Failures | Local evidence |
| --- | ---: | ---: | ---: | --- |
| Mac full unit suite | 253 | 15 | 0 | `build/chapter2-macos-unit.xcresult` |
| Mac full UI suite, signed runner | 17 | 1 | 0 | `build/chapter2-macos-ui.xcresult` |
| iPhone full unit suite | 249 | 15 | 0 | `build/chapter2-ios-unit.xcresult` |
| iPhone full UI suite | 18 | 1 | 0 | `build/chapter2-ios-ui.xcresult` |
| iPhone local StoreKit + paywall gate audit | 28 | 0 | 0 | `build/task-2.3-focused-final.xcresult` |

Each result bundle has a matching `.log`. The full suites use `BookmarkCollections`; the local StoreKit run uses `Tucked Audit`. The 15 unit skips and one UI skip are expected audit-only purchase cases. Local StoreKit audit coverage is separate from physical-device purchase acceptance. An initial audit attempt was interrupted after an Apple Account prompt; the final run verified Xcode-local transactions and passed without skips.

Both `BookmarkCollections` and `BookmarkShareExtension` generic iOS Simulator builds pass. The native Mac app build passes with normal signing. Final build logs are `build/task-2.4-app-build.log`, `build/task-2.4-extension-build.log`, and `build/task-2.4-macos-build.log`. Task-scoped regression results are retained in `build/task-2.*` and are not added to full-suite counts.

## Visual checks — blocked, not passed

The parent opened the approved simulator in the Device panel. Installation through its bound command failed with `DEVICE_IN_USE`: owner `t3-a044af77abb1e783618d12b0`. The suggested `device status` command is unavailable through that wrapper. Geoff reported releasing the session; the retry returned the same owner. No takeover, other simulator, or alternate UI driver was used.

Still inspect: add `https://www.apple.com` and rapid subsequent links without backgrounding; confirm title/preview arrival and request counts; inspect paywall price/loading/unavailable states; inspect the library-open failure screen and normal startup. No screenshot proves these changed flows yet.

Failure-screen check can safely launch Debug with `-ui-testing -simulate-store-open-failure`; both flags are required, no store opens, and no library is seeded. Omit the failure flag for the seeded in-memory success control. Ordinary `-ui-testing` disables live enrichment and StoreKit; it cannot prove the live-preview or product-loading paths.

## Acceptance boundaries

The [two-device purge/restore check](cloudkit-device-matrix.md#chapter-2-purgerestore--2026-11-09) remains pending. Geoff accepted the local-only purge visibility limit. Tests use in-memory stores and do not prove CloudKit convergence. Newer-record import follows the existing `modifiedAt` semantics, including non-edit writes; [DECISIONS](../../DECISIONS.md) records that limit.

Task reviews passed for enrichment, purge, paywall, and the newer-date import safeguard. Final Chapter 2 and Task 2.4 review remains in progress. No release, upload, submission, push, or Chapter 2 merge is authorized by these results.
