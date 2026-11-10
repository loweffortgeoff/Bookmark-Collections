# Review fixes, Chapter 4 — local verification

Branch: `dev/chapter4-import-edit-dates`, based on `8a42175`. Final app/test source: `92cb26a`. No merge or push is authorized.
Machine: Mac mini (Mac18,5), macOS 27.2 (26B123), Xcode 27.2 (27B52). iPhone checks use only iPhone 18 Pro, iOS 27.0, UUID `204520A6-E5B5-447D-8A6B-028317014DD8`.

## Policies and regression evidence

- F17: skip incoming links whose ID belongs to an image or snippet, report them in the existing import summary, and apply the same rule before checking capacity. Cover both kinds, active/deleted items, older/equal/newer backups, mixed imports, and free-limit boundaries.
- F21: opens update Last Opened only; successful metadata fetches and Refresh Preview preserve Date Modified. Regression tests reload persisted values and confirm that later backup edits still apply. Explicit organization, deletion, and restore changes continue to advance Date Modified.
- The focused run reproduced the old collision, capacity, and edit-date failures (`build/chapter4/red.xcresult`). After the fix, all 54 focused cases passed (`build/chapter4/green.xcresult`).

## Independent review follow-up

Claude Opus 5.5 (max) reviewed `8a42175..aedc0c1` read-only. The review found one related regression: equal-date backups could erase later opens after opening stopped advancing Date Modified. The parent reproduced it with `testRestoreKeepsLatestOpenHistoryForLinksAndSnippets`, then fixed both import paths to keep the later local/backup Last Opened date (`92cb26a`). The test covers links/snippets, equal/newer edit dates, and absent/earlier/later backup open dates; it also checks Forgotten. The five-case date run failed before the fix (12 assertions in the new test), and all 19 focused date/import cases passed after it (`review-red.xcresult`, `review-green.xcresult`).

The parent corrected the stale thumbnail cache comment. The cache still uses both edit and metadata refresh dates; no thumbnail behavior changed. No second review was requested; the follow-up is verified by regression tests and the final suites below.

Review rulings: preserving open history is part of the F21 correction, so restore cannot clear usage history. Keep the existing future-kind fallback, explicit repeat-save dates, conflict summary labels, and preview reset on import; their limits remain that unknown kinds read as links, repeat saves advance edit dates, conflicts appear under Invalid Lines, and restores refetch previews.

## Automated checks

| Check | Cases, including skips | Skipped | Failures | Local evidence |
| --- | ---: | ---: | ---: | --- |
| Mac full unit suite | 270 | 15 | 0 | `build/chapter4/mac-final-unit.xcresult` |
| iPhone full unit suite | 266 | 15 | 0 | `build/chapter4/iphone-final-unit.xcresult` |
| Mac full UI suite, signed runner | 19 | 1 | 0 | `build/chapter4/mac-final-ui.xcresult` |
| iPhone full UI suite | 19 | 1 | 0 | `build/chapter4/iphone-final-ui.xcresult` |

All final suites ran after commit `92cb26a`; only documentation changed afterwards. The 15 unit skips and one UI skip per platform are the existing audit-only purchase cases. Each result bundle has a matching `.log`. The earlier full suites at `aedc0c1` also passed (269/265 unit cases and 19 UI cases per platform).

The signed generic iOS build and the `BookmarkCollections` and `BookmarkShareExtension` iPhone simulator builds pass at `92cb26a`. Logs under `build/chapter4/`: `ios-final-build.log`, `simulator-final-app-build.log`, and `simulator-final-extension-build.log`.

## Limits

No view layout or schema changed. No manual visual inspection, physical-device sync check, or release acceptance was performed. Existing Date Modified values are retained. F1 keeps its accepted interim policy; F15 still needs host samples, F24 remains conditional on returning Share errors, and F22/F23/image panning remain backlog.
