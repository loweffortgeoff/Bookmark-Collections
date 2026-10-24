# Fixture validation

On 2026-10-23, one native Mac XCTest passed against LibraryImportService from f34b8c6. It exercised all five JSON files with free access locked, then unlocked, then locked again above ten. All assertions passed; no tests failed or skipped.

Assertions covered ten-item mixed import, same-ID field updates, new-ID normalized-URL reconciliation retaining the original UUID, byte-identical exported user data after rejection, no rejected collection, two-item expansion after unlock, and duplicate-only updates while locked above ten.

The first test invocation stopped at compilation because the test target defaulted to macOS 14 while the app requires macOS 15. The retry used MACOSX_DEPLOYMENT_TARGET=15.0 and passed on the Mac mini, macOS 27.0.1 / Xcode 27.1. No app or project code changed.

The temporary test source and xcresult remain in the ignored .superpowers/sdd/2026-10-23-testflight evidence folder. This automated check does not replace the TestFlight device checks in README.md.
