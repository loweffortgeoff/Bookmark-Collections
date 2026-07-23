# macOS Quick Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make **Save to Tucked** immediately persist and dismiss on macOS while preserving the existing interactive iOS and iPadOS Share Sheet.

**Architecture:** Add a testable `ShareCaptureModel.quickSave(from:)` operation that composes the existing load and repository-backed save paths with fixed organization defaults. A macOS-only SwiftUI progress/error view invokes that operation, while the iOS controller continues hosting the existing `ShareCaptureView` unchanged.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SwiftData, XCTest, `NSItemProvider`, and the existing system-framework-only Share extension.

## Global Constraints

- Support iOS/iPadOS 18 and macOS 15.
- Use system Apple frameworks only; add no package dependency.
- Keep `BookmarkCollections` target, folder, and bundle identifier namespaces unchanged.
- Keep App Group `group.com.loweffortapps.BookmarkCollections` and CloudKit container `iCloud.com.loweffortapps.BookmarkCollections` unchanged.
- A successful Share request must follow a durable local SwiftData save; metadata and CloudKit must not block capture.
- macOS Quick Save always supplies no collection and Favorite off.
- iOS and iPadOS retain their existing Collection picker, Favorite toggle, Cancel, and Save controls.
- Preserve repository-owned URL normalization, update, restore, duplicate, and image-save semantics.
- Do not claim CloudKit Production or cross-device verification from local Share testing.

---

## File Structure

- Modify `BookmarkShareExtension/ShareCaptureModel.swift` to expose the
  platform-neutral quick-save operation.
- Create `BookmarkShareExtension/MacQuickSaveView.swift` for the macOS-only
  progress, Retry, and Cancel presentation.
- Modify `BookmarkShareExtension/ShareViewController.swift` to select the
  quick-save view only in the AppKit host.
- Modify `BookmarkCollectionsTests/ShareCaptureModelTests.swift` for quick-save
  defaults, completion ordering, load failure, and retry behavior.
- Modify `README.md`, `CHANGELOG.md`, and `DECISIONS.md` to document the
  intentional platform difference.
- Modify `docs/verification/cloudkit-device-matrix.md` only with evidence
  observed during the signed live flow.

The extension folder is a `PBXFileSystemSynchronizedRootGroup`, so the new
Swift file is discovered automatically. Do not edit `project.pbxproj` merely
to add it.

---

### Task 1: Add the Testable Quick-Save Operation

**Files:**
- Modify: `BookmarkCollectionsTests/ShareCaptureModelTests.swift`
- Modify: `BookmarkShareExtension/ShareCaptureModel.swift`

**Interfaces:**
- Consumes: `ShareCaptureModel.load(from:)` and
  `ShareCaptureModel.save(collectionID:favorite:)`.
- Produces:
  `func quickSave(from providers: [NSItemProvider]) async`, which loads one
  supported item and, only when ready, saves it with `nil` collection and
  `false` Favorite.

- [ ] **Step 1: Add failing tests for defaults and completion ordering**

Add these tests inside `ShareCaptureModelTests`:

```swift
func testQuickSaveUsesDefaultOrganizationAndCompletesAfterSave() async throws {
    var saveWasCalled = false
    var receivedCollectionID: UUID? = UUID()
    var receivedFavorite = true
    var completedAfterSave = false
    let model = ShareCaptureModel(
        collections: [],
        saveAction: { capture, collectionID, favorite in
            saveWasCalled = true
            receivedCollectionID = collectionID
            receivedFavorite = favorite
            return .created(
                Bookmark(
                    urlString: capture.urlString,
                    normalizedURLString: capture.urlString
                )
            )
        },
        onComplete: {
            completedAfterSave = saveWasCalled
        }
    )
    let provider = NSItemProvider(
        object: NSURL(string: "https://example.com/quick-save")!
    )

    await model.quickSave(from: [provider])

    XCTAssertTrue(saveWasCalled)
    XCTAssertNil(receivedCollectionID)
    XCTAssertFalse(receivedFavorite)
    XCTAssertTrue(completedAfterSave)
    XCTAssertEqual(model.state, .saved)
}

func testQuickSaveUnsupportedInputDoesNotSaveOrComplete() async {
    var didSave = false
    var didComplete = false
    let model = ShareCaptureModel(
        collections: [],
        saveAction: { _, _, _ in
            didSave = true
            return .created(
                Bookmark(urlString: "", normalizedURLString: "")
            )
        },
        onComplete: {
            didComplete = true
        }
    )
    let provider = NSItemProvider(
        item: Data([0x01]) as NSData,
        typeIdentifier: UTType.data.identifier
    )

    await model.quickSave(from: [provider])

    XCTAssertFalse(didSave)
    XCTAssertFalse(didComplete)
    guard case let .failed(message) = model.state else {
        return XCTFail("Expected unsupported input to fail")
    }
    XCTAssertTrue(message.localizedCaseInsensitiveContains("web link"))
}
```

- [ ] **Step 2: Add the failing retry test**

Add:

```swift
func testQuickSaveCanRetryAfterSaveFailure() async {
    var attempts = 0
    var completions = 0
    let model = ShareCaptureModel(
        collections: [],
        saveAction: { capture, _, _ in
            attempts += 1
            if attempts == 1 {
                throw TestError.storeUnavailable
            }
            return .created(
                Bookmark(
                    urlString: capture.urlString,
                    normalizedURLString: capture.urlString
                )
            )
        },
        onComplete: {
            completions += 1
        }
    )
    let provider = NSItemProvider(
        object: NSURL(string: "https://example.com/quick-save-retry")!
    )

    await model.quickSave(from: [provider])

    XCTAssertEqual(attempts, 1)
    XCTAssertEqual(completions, 0)
    guard case .failed = model.state else {
        return XCTFail("Expected the first save to fail")
    }

    await model.quickSave(from: [provider])

    XCTAssertEqual(attempts, 2)
    XCTAssertEqual(completions, 1)
    XCTAssertEqual(model.state, .saved)
}
```

- [ ] **Step 3: Run the new tests and verify the intended failure**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests/testQuickSaveUsesDefaultOrganizationAndCompletesAfterSave \
  -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests/testQuickSaveUnsupportedInputDoesNotSaveOrComplete \
  -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests/testQuickSaveCanRetryAfterSaveFailure
```

Expected: build failure stating that `ShareCaptureModel` has no member
`quickSave`.

- [ ] **Step 4: Implement the minimal quick-save composition**

Add this method immediately after `load(from:)` in `ShareCaptureModel`:

```swift
func quickSave(from providers: [NSItemProvider]) async {
    await load(from: providers)
    guard state == .ready else { return }
    save(collectionID: nil, favorite: false)
}
```

Do not duplicate provider parsing or repository persistence in this method.
The synchronous `save` call must remain the final operation after successful
loading so completion still follows the durable write.

- [ ] **Step 5: Run the focused Share capture suite**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests
```

Expected: all `ShareCaptureModelTests` pass, including the three new quick-save
tests and the existing interactive save, duplicate update, restore, and image
tests.

- [ ] **Step 6: Commit the model behavior**

```bash
git add \
  BookmarkShareExtension/ShareCaptureModel.swift \
  BookmarkCollectionsTests/ShareCaptureModelTests.swift
git commit -m "feat: add Share extension quick save"
```

---

### Task 2: Replace the macOS Confirmation Form with Quick Save

**Files:**
- Create: `BookmarkShareExtension/MacQuickSaveView.swift`
- Modify: `BookmarkShareExtension/ShareViewController.swift`
- Preserve unchanged: `BookmarkShareExtension/ShareCaptureView.swift`

**Interfaces:**
- Consumes:
  `ShareCaptureModel.quickSave(from:)`,
  `ShareCaptureModel.state`, the AppKit controller's flattened providers, and
  its existing cancel callback.
- Produces:
  `MacQuickSaveView(model:providers:onCancel:)`, a macOS-only progress/error
  surface with no organization controls.

- [ ] **Step 1: Create the macOS quick-save view**

Create `BookmarkShareExtension/MacQuickSaveView.swift` with:

```swift
import SwiftUI

#if os(macOS)
struct MacQuickSaveView: View {
    @ObservedObject var model: ShareCaptureModel
    let providers: [NSItemProvider]
    let onCancel: () -> Void

    var body: some View {
        Group {
            if case let .failed(message) = model.state {
                ContentUnavailableView {
                    Label(
                        "Couldn’t Save to Tucked",
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") {
                        Task {
                            await model.quickSave(from: providers)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Cancel", action: onCancel)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Saving to Tucked…")
                }
            }
        }
        .frame(minWidth: 360, minHeight: 200)
        .task {
            guard model.state == .idle else { return }
            await model.quickSave(from: providers)
        }
    }
}
#endif
```

This view deliberately has no `Picker`, `Toggle`, preview, or confirmation
button. Retry reuses the same providers; completion dismisses the host before
the transient `.saved` state needs a separate presentation.

- [ ] **Step 2: Route only the AppKit host to Quick Save**

In the macOS `ShareViewController.loadView()`, change:

```swift
preferredContentSize = NSSize(width: 420, height: 520)
```

to:

```swift
preferredContentSize = NSSize(width: 360, height: 200)
```

In the macOS `configureCapture()`, replace:

```swift
let model = ShareCaptureModel(
    context: container.mainContext,
    metadataProvider: LinkPresentationMetadataProvider()
) { [weak self] in
    self?.extensionContext?.completeRequest(returningItems: nil)
}
host(
    ShareCaptureView(
        model: model,
        providers: inputProviders,
        onCancel: { [weak self] in self?.cancelRequest() }
    )
)
```

with:

```swift
let model = ShareCaptureModel(
    context: container.mainContext
) { [weak self] in
    self?.extensionContext?.completeRequest(returningItems: nil)
}
host(
    MacQuickSaveView(
        model: model,
        providers: inputProviders,
        onCancel: { [weak self] in self?.cancelRequest() }
    )
)
```

Do not edit the UIKit controller. Its metadata provider and
`ShareCaptureView` remain exactly as they are.

- [ ] **Step 3: Build the signed macOS app and embedded extension**

Run:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/QuickSaveDerivedData
```

Expected: `** BUILD SUCCEEDED **`, with
`BookmarkCollections.app/Contents/PlugIns/BookmarkShareExtension.appex`
present. If provisioning refresh is required, rerun with
`-allowProvisioningUpdates`; do not alter identifiers or entitlements.

- [ ] **Step 4: Verify signing and extension registration**

Run:

```bash
QUICK_SAVE_APP="build/QuickSaveDerivedData/Build/Products/Debug/BookmarkCollections.app"
QUICK_SAVE_EXTENSION="$QUICK_SAVE_APP/Contents/PlugIns/BookmarkShareExtension.appex"
codesign --verify --deep --strict --verbose=2 "$QUICK_SAVE_APP"
codesign -d --entitlements :- "$QUICK_SAVE_EXTENSION"
open "$QUICK_SAVE_APP"
pluginkit -mAvvv -p com.apple.share-services |
  rg -C 3 'com\\.loweffortapps\\.BookmarkCollections\\.ShareExtension'
```

Expected: strict nested signing passes; the extension retains App Sandbox,
outbound networking, the existing App Group, and the existing CloudKit
container; and `pluginkit` lists `Save to Tucked`.

- [ ] **Step 5: Re-run the macOS Share capture tests**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests
```

Expected: all focused tests pass after the host/view integration.

- [ ] **Step 6: Commit the macOS presentation change**

```bash
git add \
  BookmarkShareExtension/MacQuickSaveView.swift \
  BookmarkShareExtension/ShareViewController.swift
git commit -m "feat: quick save from macOS Share menus"
```

---

### Task 3: Verify Safari Quick Save and Record the Product Decision

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `DECISIONS.md`
- Modify only with observed evidence:
  `docs/verification/cloudkit-device-matrix.md`

**Interfaces:**
- Consumes: the signed, registered macOS extension from Task 2.
- Produces: a verified Safari one-action capture and documentation that
  distinguishes macOS Quick Save from the unchanged iOS confirmation flow.

- [ ] **Step 1: Perform a unique Safari quick save with Tucked closed**

Quit Tucked. In Safari, open:

```text
https://example.com/?tucked-macos-quick-save=20260723
```

Choose **Share → Save to Tucked** and verify:

1. no Collection menu, Favorite toggle, or Save confirmation appears;
2. at most a brief **Saving to Tucked…** progress panel appears;
3. the Share request dismisses on its own; and
4. Tucked did not need to open for the save to complete.

Then open Tucked and verify exactly one active bookmark exists for the
normalized URL, shows no collection, and is not a Favorite. Soft-delete this
unique verification bookmark after recording the result so it remains
recoverable in Recently Deleted.

- [ ] **Step 2: Verify the failure surface without damaging the shared store**

Use a standard host that can invoke **Save to Tucked** with an unsupported item
if one is readily available. Verify the panel remains open with
**Couldn’t Save to Tucked**, Retry, and Cancel, then choose Cancel.

If no ordinary host exposes the extension for unsupported content, record this
live sub-check as not exercised and rely on the automated unsupported-input
and retry tests. Do not corrupt, delete, or replace the App Group store to
manufacture a failure.

- [ ] **Step 3: Update the README**

After the opening paragraph, add:

```markdown
On Mac, **Save to Tucked** is a capture-first action: it saves immediately
with no collection and Favorite off, then dismisses. Collection and Favorite
can be changed later in Tucked. The iPhone and iPad Share Sheet keeps its
interactive Collection and Favorite controls.
```

In the Architecture list, replace:

```markdown
- `BookmarkShareExtension`: immediate Share Sheet validation and durable App Group save.
```

with:

```markdown
- `BookmarkShareExtension`: immediate Share validation and durable App Group
  save, using Quick Save on macOS and an interactive confirmation form on iOS.
```

- [ ] **Step 4: Update the changelog**

Under `### Added — 2026-07-23`, add a `### Changed — 2026-07-23` section:

```markdown
### Changed — 2026-07-23

- Changed the macOS **Save to Tucked** Share action to Quick Save: shared
  links and images now save immediately with no collection and Favorite off,
  avoiding the nested Collection menu inside Safari's Share surface. The
  interactive iPhone and iPad Share Sheet is unchanged.
```

Keep the earlier Added entry because the macOS Share extension capability is
still part of the release.

- [ ] **Step 5: Record the architecture/product decision**

Append:

```markdown
## 2026-07-23 (macOS Share uses capture-first Quick Save)

- **Decision:** On macOS, choosing **Save to Tucked** immediately saves the
  shared link or image with no collection and Favorite off. The extension may
  show brief progress and exposes Retry/Cancel only after failure. iOS and
  iPadOS retain the interactive Collection and Favorite form.
- **Why:** Safari hosts the extension in a ShareKit-owned system dialog, so
  the Collection picker becomes a native menu nested inside Safari's Share
  interaction. Live verification showed that the menu functions but the
  layered interaction is awkward and is not Debug-specific. Tucked already
  persists directly into the shared App Group store, so capture can finish
  without launching the containing app.
- **Alternative considered:** Keep full cross-platform UI parity — rejected
  because the macOS host interaction is needlessly layered. Add a preference
  or a second Share action — rejected as extra settings/target complexity for
  a capture path intended to be immediate.
```

- [ ] **Step 6: Update verification evidence precisely**

In `docs/verification/cloudkit-device-matrix.md`, revise only the macOS Share
rows and the dated macOS Share evidence section necessary to record:

- the exact commit/build product exercised;
- Safari Quick Save completing while Tucked was closed;
- absence of Collection/Favorite/Save controls;
- the resulting no-collection, Favorite-off bookmark;
- whether the live failure surface was exercised; and
- that iOS behavior was covered by automated regression rather than changed.

Preserve the existing signed entitlement/registration evidence and all
CloudKit Production, TestFlight, cross-device, and release-gate caveats.

- [ ] **Step 7: Validate and commit documentation**

Run:

```bash
git diff --check
git diff -- \
  README.md \
  CHANGELOG.md \
  DECISIONS.md \
  docs/verification/cloudkit-device-matrix.md
```

Expected: no whitespace errors, no claim beyond observed evidence, and no
change to `TODO.md`.

Then commit:

```bash
git add \
  README.md \
  CHANGELOG.md \
  DECISIONS.md \
  docs/verification/cloudkit-device-matrix.md
git commit -m "docs: record macOS quick save behavior"
```

---

### Task 4: Run Cross-Platform Regression and Final Review

**Files:**
- Review: all files changed by Tasks 1–3

**Interfaces:**
- Consumes: the complete macOS Quick Save implementation and documentation.
- Produces: final evidence that macOS capture works and iOS behavior still
  compiles and passes its focused regression suite.

- [ ] **Step 1: Run the complete native macOS unit suite**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests
```

Expected: all native macOS unit tests pass.

- [ ] **Step 2: Run the native macOS UI suite**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsUITests
```

Expected: all UI tests pass with the runner normally signed.

- [ ] **Step 3: Run the focused iOS Share regression suite**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests
```

Expected: all Share capture tests pass on the iPhone simulator. If that
simulator is unavailable, list installed devices with
`xcrun simctl list devices available`, substitute one installed iPhone, and
record the actual destination.

- [ ] **Step 4: Build the signed generic iOS app and extension**

Run:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'generic/platform=iOS'
```

Expected: `** BUILD SUCCEEDED **` with the unchanged interactive iOS Share
extension embedded. If provisioning needs refresh, add
`-allowProvisioningUpdates`; do not change identifiers.

- [ ] **Step 5: Review the complete branch delta**

Run:

```bash
git diff --check
git status --short --branch
git diff 55db399...HEAD -- \
  BookmarkShareExtension \
  BookmarkCollectionsTests \
  README.md \
  CHANGELOG.md \
  DECISIONS.md \
  TODO.md \
  docs/verification
```

Expected:

- macOS hosts `MacQuickSaveView`;
- UIKit still hosts `ShareCaptureView`;
- Quick Save supplies `nil` collection and `false` Favorite;
- completion still follows successful persistence;
- no identifier, entitlement, or Xcode project change was introduced;
- documentation distinguishes observed local Share behavior from remaining
  CloudKit release gates; and
- the worktree is clean.

- [ ] **Step 6: Commit only verification-driven corrections**

If Steps 1–5 expose a defect, make the smallest root-cause correction, rerun
the failed command and its relevant counterpart, and commit only that fix:

```bash
git add \
  BookmarkShareExtension/ShareCaptureModel.swift \
  BookmarkShareExtension/MacQuickSaveView.swift \
  BookmarkShareExtension/ShareViewController.swift \
  BookmarkCollectionsTests/ShareCaptureModelTests.swift \
  README.md \
  CHANGELOG.md \
  DECISIONS.md \
  docs/verification/cloudkit-device-matrix.md
git commit -m "fix: correct macOS quick save regression"
```

If verification required no source or documentation correction, do not create
an empty commit.
