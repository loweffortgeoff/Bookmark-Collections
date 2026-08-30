# Tucked Paywall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 10-bookmark free tier and a $7.99 lifetime StoreKit unlock to Tucked.

**Architecture:** A shared pure limit rule protects every create path. A StoreKit 2 storefront exposes the lifetime entitlement to SwiftUI. The containing app presents the paywall; the Share extension returns a clear limit-reached error.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, StoreKit 2, XCTest.

**Spec:** `docs/superpowers/specs/2026-08-29-tucked-paywall-design.md`

## Global Constraints

- Support iOS 18 and macOS 15 with one shared non-consumable product: `com.loweffortapps.BookmarkCollections.lifetime`.
- Count active links, images, and snippets; do not charge for export, deletion, or access.
- Do not show StoreKit purchase UI from the Share extension.
- Use a compiled `PAYWALL_ENABLED` build setting. Beta disables it and Release enables it.
- Do not merge this branch.

---

### Task 1: Free-tier domain rule

**Files:**
- Create: `BookmarkCollections/Domain/BookmarkLimit.swift`
- Modify: `BookmarkCollections/Domain/BookmarkRepository.swift`
- Test: `BookmarkCollectionsTests/BookmarkLimitTests.swift`

**Interfaces:**
- Produces: `BookmarkLimit.canCreate(activeBookmarkCount:isUnlocked:) -> Bool` and `BookmarkRepository.LimitError.limitReached`.

- [ ] **Step 1:** Write failing tests for the tenth free create, the eleventh blocked create, and an unlocked create.
- [ ] **Step 2:** Run `xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/BookmarkLimitTests` and confirm it fails because the rule is absent.
- [ ] **Step 3:** Add the pure rule and enforce it before new links, images, snippets, restores, and imports create active records.
- [ ] **Step 4:** Rerun the focused test target and confirm it passes.

### Task 2: StoreKit and app paywall

**Files:**
- Create: `BookmarkCollections/Domain/Storefront.swift`
- Create: `BookmarkCollections/Features/Paywall/PaywallView.swift`
- Modify: `BookmarkCollections/BookmarkCollectionsApp.swift`
- Modify: `BookmarkCollections/Features/Library/LibraryRootView.swift`
- Modify: creation views and Settings import handling
- Test: `BookmarkCollectionsTests/BookmarkLimitTests.swift`

**Interfaces:**
- Consumes: `BookmarkRepository.LimitError.limitReached`.
- Produces: `Storefront.isUnlocked`, `Storefront.purchase()`, and `Storefront.restorePurchases()`.

- [ ] **Step 1:** Add a failing test that verifies a capped repository reports the limit error rather than saving an eleventh item.
- [ ] **Step 2:** Run the focused domain suite and confirm the new test fails.
- [ ] **Step 3:** Inject storefront state, show the paywall for capped app saves, and retain free export/deletion/access.
- [ ] **Step 4:** Rerun the focused domain suite and confirm it passes.

### Task 3: Extension and build configuration

**Files:**
- Modify: `BookmarkShareExtension/ShareCaptureModel.swift`
- Modify: `BookmarkCollections.xcodeproj/project.pbxproj`
- Create: `BookmarkCollections.xcodeproj/xcshareddata/xcschemes/Tucked Beta.xcscheme`
- Create: `BookmarkCollections.xcodeproj/xcshareddata/xcschemes/Tucked Release.xcscheme`

**Interfaces:**
- Consumes: shared `BookmarkRepository.LimitError.limitReached` and `PAYWALL_ENABLED`.
- Produces: Beta archive with the cap bypassed and Release archive with the cap enabled.

- [ ] **Step 1:** Add a failing Share Capture test for the limit-reached result.
- [ ] **Step 2:** Run `xcodebuild test -project BookmarkCollections.xcodeproj -scheme BookmarkCollections -destination 'platform=macOS' -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests` and confirm it fails.
- [ ] **Step 3:** Give the extension a limit-reached message, add target Beta configurations, and create the two named schemes.
- [ ] **Step 4:** Rerun the focused Share Capture suite and confirm it passes.

### Task 4: Verify and record

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `DECISIONS.md`
- Modify: `TODO.md`

- [ ] **Step 1:** Run the macOS unit suite and build both Release archives.
- [ ] **Step 2:** Update project tracking with the paid-unlock decision and verification result.
- [ ] **Step 3:** Review the diff and commit with `feat: add Tucked lifetime paywall`.
