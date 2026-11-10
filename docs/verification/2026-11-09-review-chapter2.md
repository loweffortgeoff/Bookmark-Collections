# Review fixes, Chapter 2 — local verification

Full-suite source: `b9197be` on `fix/review-enrichment-purchase`. The final URL-change guard and its focused verification are recorded below. Chapter 1 was merged locally to `main` at `411b8e8` with Geoff’s authorization. Chapter 2 is not merged or pushed.

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

## Visual checks — completed on iPhone 18 Pro

The earlier `DEVICE_IN_USE` claim cleared after Geoff released it. The parent used only the bound T3 device command, inspected screenshots, and closed its own session afterwards. No user store was opened or changed.

- Debug failure launch (`-ui-testing -simulate-store-open-failure`) showed the planned title, restart guidance, and Support link. [Screenshot](../../build/chapter2-visuals/store-failure.png).
- The seeded in-memory success launch opened the normal library. The final uninstrumented app was reinstalled and checked again after the URL guard. [Screenshot](../../build/chapter2-visuals/final-success-control.png).
- Settings → Unlock showed the no-product paywall without the invented price. This ordinary UI-test launch intentionally skips StoreKit; it verifies layout, not a live catalog failure. [Screenshot](../../build/chapter2-visuals/paywall-no-product.png).
- Added Apple, Swift.org, and Python.org in succession. All gained titles and preview images without backgrounding. [Apple](../../build/chapter2-visuals/apple-live-preview.png), [three previews](../../build/chapter2-visuals/three-live-previews.png).

Live metadata used a temporary Debug build that enabled only metadata networking under `-ui-testing`; the library stayed in memory and StoreKit stayed isolated. The scheduling and provider code were unchanged apart from temporary print markers. Source was restored byte for byte afterwards. The log stream did not capture those markers, so request counts and overlapping rapid-add timing were not measured. No claim is made about Apple's cancellation behavior. Loaded-price and loading-spinner UI states were not captured interactively; catalog failure/retry and purchase state have separate local StoreKit audit coverage.

## Final review follow-up

Final review approved `b9197be`, including the Task 2.4 spec and quality gate, with no Critical or Important findings. The parent fixed its small URL-change finding: discard metadata when the requested URL changes, and include the URL with persistent identity in the pending task key so the replacement request restarts.

After that final guard, all 30 metadata tests passed on iPhone and Mac, with zero failures or skips (`build/chapter2-url-guard-ios.xcresult`, `build/chapter2-url-guard-macos.xcresult`). Both app targets compiled in those test builds, and the standalone Share Extension simulator build passed (`build/chapter2-url-guard-extension.log`). The four full-suite results above precede this narrow follow-up; the affected suites were rerun. No temporary instrumentation remains.

## Acceptance boundaries

The [two-device purge/restore check](cloudkit-device-matrix.md#chapter-2-purgerestore--2026-11-09) passed per Geoff on 2026-11-10 at 03:50 am: iPhone 17 / iOS 27.1.2 and iPhone 17 Pro / iOS 27.3 Developer Beta 1, both Xcode-installed Build 15 at `126b913`, with the restored link in `Dev Work` on both. Latency was not supplied. Geoff accepted the local-only purge visibility limit. Tests use in-memory stores and do not prove CloudKit convergence. Newer-record import follows the existing `modifiedAt` semantics, including non-edit writes; [DECISIONS](../../DECISIONS.md) records that limit.

Task reviews passed for enrichment, purge, paywall, and the newer-date import safeguard. Final Chapter 2 and Task 2.4 review passed; the small follow-up was checked by the parent and focused tests. No release, upload, submission, push, or Chapter 2 merge is authorized by these results.
