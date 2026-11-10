# Review fixes, Chapter 4 — local verification

Branch: `dev/chapter4-import-edit-dates`, based on `8a42175`. No merge or push is authorized.
Machine: Mac mini (Mac18,5), macOS 27.2 (26B123), Xcode 27.2 (27B52). iPhone checks use only iPhone 18 Pro, iOS 27.0, UUID `204520A6-E5B5-447D-8A6B-028317014DD8`.

## Policies and regression evidence

- F17: skip incoming links whose ID belongs to an image or snippet, report them in the existing import summary, and apply the same rule before checking capacity. Cover both kinds, active/deleted items, older/equal/newer backups, mixed imports, and free-limit boundaries.
- F21: opens update Last Opened only; successful metadata fetches and Refresh Preview preserve Date Modified. Regression tests reload persisted values and confirm that later backup edits still apply. Explicit organization, deletion, and restore changes continue to advance Date Modified.
- The focused run reproduced the old collision, capacity, and edit-date failures (`build/chapter4/red.xcresult`). After the fix, all 54 focused cases passed (`build/chapter4/green.xcresult`).

## Automated checks

| Check | Cases, including skips | Skipped | Failures | Local evidence |
| --- | ---: | ---: | ---: | --- |
| Mac full unit suite | 269 | 15 | 0 | `build/chapter4/mac-unit.xcresult` |
| iPhone full unit suite | 265 | 15 | 0 | `build/chapter4/iphone-unit.xcresult` |
| Mac full UI suite, signed runner | 19 | 1 | 0 | `build/chapter4/mac-ui.xcresult` |
| iPhone full UI suite | 19 | 1 | 0 | `build/chapter4/iphone-ui.xcresult` |

The 15 unit skips and one UI skip per platform are the existing audit-only purchase cases. Each result bundle has a matching `.log`.

The signed generic iOS build and the `BookmarkCollections` and `BookmarkShareExtension` iPhone simulator builds pass. Logs: `build/chapter4/ios-build.log`, `simulator-app-build.log`, and `simulator-extension-build.log`.

## Limits

No view layout or schema changed. No manual visual inspection, physical-device sync check, or release acceptance was performed. Existing Date Modified values are retained. F1 keeps its accepted interim policy; F15 still needs host samples, F24 remains conditional on returning Share errors, and F22/F23/image panning remain backlog.
