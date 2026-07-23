# macOS Share Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Tucked's existing Share extension available on macOS with full iOS parity for one link, text containing a link, or one image, including Collection and Favorite choices.

**Architecture:** Convert the existing `BookmarkShareExtension` target into a multiplatform app extension. Keep `ShareCaptureModel`, the SwiftUI form, repository persistence, App Group store, and CloudKit configuration shared; isolate only the UIKit/AppKit host controller and platform image decoding behind conditional compilation.

**Tech Stack:** Swift 6, SwiftUI, UIKit, AppKit, SwiftData, CloudKit, Uniform Type Identifiers, Xcode 26.6, XCTest, system frameworks only.

## Global Constraints

- Support iOS/iPadOS 18 and macOS 15.
- Use only system Apple frameworks; add no package dependency.
- Keep `BookmarkCollections` as the Xcode target and bundle identifier namespace.
- Keep app bundle identifier `com.loweffortapps.BookmarkCollections`.
- Keep Share extension bundle identifier `com.loweffortapps.BookmarkCollections.ShareExtension`.
- Keep App Group `group.com.loweffortapps.BookmarkCollections`.
- Keep CloudKit container `iCloud.com.loweffortapps.BookmarkCollections`.
- SwiftData remains the local source of truth; CloudKit and metadata never block Save.
- A successful extension completion occurs only after the local repository save succeeds.
- Accept at most one HTTP/HTTPS link, text containing a valid link, or one image.
- Do not add drag-and-drop, file/photo import, browser extensions, background services, or multi-item capture.
- Do not redesign the current iOS Share experience.
- Do not record local build or simulator results as production CloudKit evidence.

---

## File Structure

- `BookmarkShareExtension/ShareCaptureView.swift`: shared confirmation form plus a private UIKit/AppKit image bridge.
- `BookmarkShareExtension/ShareViewController.swift`: conditionally compiled iOS and macOS native host controllers; shared storage-failure view.
- `BookmarkShareExtension/BookmarkShareExtensionMac.entitlements`: macOS extension sandbox, outbound-network, App Group, and CloudKit capabilities.
- `BookmarkCollections.xcodeproj/project.pbxproj`: make the existing extension target and embedding relationship build for iOS and macOS; select platform-specific entitlements.
- `BookmarkCollectionsTests/ShareCaptureModelTests.swift`: characterize full-parity collection/Favorite persistence for image capture.
- `README.md`: describe Share Sheet capture on both supported platform families.
- `CHANGELOG.md`: record the new macOS Share capability and verification.
- `DECISIONS.md`: supersede the former iOS-only image-capture decision.
- `TODO.md`: distinguish completed Mac Share capture from still-deferred file picker and drag-and-drop paths.
- `docs/verification/cloudkit-device-matrix.md`: record only observed macOS extension/build/live-flow evidence.

---

### Task 1: Characterize Full-Parity Image Persistence

**Files:**
- Modify: `BookmarkCollectionsTests/ShareCaptureModelTests.swift`

**Interfaces:**
- Consumes: `ShareCaptureModel.init(context:metadataProvider:onComplete:)`, `ShareCaptureModel.load(from:)`, and `ShareCaptureModel.save(collectionID:favorite:)`.
- Produces: regression coverage proving an image shared on any platform retains both the chosen collection and Favorite state.

- [ ] **Step 1: Add the focused parity test**

Add this test immediately after `testImageSavePersistsImageBookmark()`:

```swift
func testImageSaveAssignsCollectionAndFavorite() async throws {
    let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
    let collection = BookmarkCollection(name: "Reference", sortPosition: 0)
    container.mainContext.insert(collection)
    try container.mainContext.save()
    let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
    let provider = NSItemProvider(
        item: try onePixelPNG() as NSData,
        typeIdentifier: UTType.png.identifier
    )
    await model.load(from: [provider])

    model.save(collectionID: collection.id, favorite: true)

    let bookmark = try XCTUnwrap(
        container.mainContext.fetch(FetchDescriptor<Bookmark>()).first
    )
    XCTAssertEqual(bookmark.kind, .image)
    XCTAssertEqual(bookmark.collection?.id, collection.id)
    XCTAssertTrue(bookmark.isFavorite)
}
```

- [ ] **Step 2: Run the focused test**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests/testImageSaveAssignsCollectionAndFavorite
```

Expected: PASS. This is a characterization test for already-shared repository
behavior, not a production-code change. If it fails, stop and correct the
existing shared save path before adding platform hosting.

- [ ] **Step 3: Run the complete capture-model test class**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests
```

Expected: all `ShareCaptureModelTests` pass, including direct URL, text URL,
unsupported input, durable completion ordering, save failure, duplicate update,
restore, image load, image save, and junk-image rejection.

- [ ] **Step 4: Commit the characterization**

```bash
git add BookmarkCollectionsTests/ShareCaptureModelTests.swift
git commit -m "test: cover image share collection parity"
```

---

### Task 2: Make the Existing Share Extension Multiplatform

**Files:**
- Modify: `BookmarkCollections.xcodeproj/project.pbxproj`
- Create: `BookmarkShareExtension/BookmarkShareExtensionMac.entitlements`
- Modify: `BookmarkShareExtension/ShareCaptureView.swift`
- Modify: `BookmarkShareExtension/ShareViewController.swift`

**Interfaces:**
- Consumes: `ShareCaptureView(model:providers:onCancel:)`,
  `ModelContainerFactory.make(inMemory:cloudKit:)`,
  `LinkPresentationMetadataProvider`, and `NSExtensionContext`.
- Produces: one `BookmarkShareExtension.appex` product that compiles for iOS
  and macOS and is embedded by the matching `BookmarkCollections.app`.

- [ ] **Step 1: Enable the macOS build graph before changing source**

In both extension build configurations in
`BookmarkCollections.xcodeproj/project.pbxproj`, make these exact setting
changes:

```text
MACOSX_DEPLOYMENT_TARGET = 15.0;
SDKROOT = auto;
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx";
"CODE_SIGN_ENTITLEMENTS[sdk=macosx*]" = BookmarkShareExtension/BookmarkShareExtensionMac.entitlements;
```

Keep the existing unqualified setting:

```text
CODE_SIGN_ENTITLEMENTS = BookmarkShareExtension/BookmarkShareExtension.entitlements;
```

Remove `platformFilter = ios;` from both:

```text
A1E000000000000000000018 /* BookmarkShareExtension.appex in Embed Foundation Extensions */
A1E000000000000000000035 /* PBXTargetDependency */
```

This lets the containing app build, depend on, and embed the same target for
the active platform while preserving the existing iOS entitlements.

- [ ] **Step 2: Run the macOS build to prove platform-specific source is the blocker**

Run:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL in the extension source because `UIKit` is unavailable on
macOS, proving the target is now entering the macOS build graph.

- [ ] **Step 3: Add the macOS extension entitlements**

Create `BookmarkShareExtension/BookmarkShareExtensionMac.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.loweffortapps.BookmarkCollections</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.loweffortapps.BookmarkCollections</string>
    </array>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

The network-client entitlement permits optional link metadata fetching. The
App Group and CloudKit identifiers must exactly match the containing app.

- [ ] **Step 4: Bridge platform image decoding in the shared SwiftUI view**

Replace the imports at the top of `ShareCaptureView.swift` with:

```swift
import SwiftUI

#if os(iOS)
import UIKit
private typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
private typealias PlatformImage = NSImage
#endif
```

Replace:

```swift
if let previewData = capture.previewImageData,
   let preview = UIImage(data: previewData) {
    Image(uiImage: preview)
```

with:

```swift
if let previewData = capture.previewImageData,
   let preview = PlatformImage(data: previewData) {
    Image(platformImage: preview)
```

Append this private bridge after `ShareCaptureView`:

```swift
private extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}
```

Do not change the form, title, picker, Favorite toggle, Cancel/Save actions, or
state handling.

- [ ] **Step 5: Add an AppKit host beside the UIKit host**

In `ShareViewController.swift`, replace the unconditional `import UIKit` with:

```swift
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
```

Wrap the existing `ShareViewController: UIViewController` declaration and its
implementation in:

```swift
#if os(iOS)
// Existing UIViewController implementation, unchanged.
#endif
```

Then insert this macOS implementation before `ShareStoreFailureView`:

```swift
#if os(macOS)
@MainActor
final class ShareViewController: NSViewController {
    private var container: ModelContainer?
    private var hostedController: NSViewController?

    override func loadView() {
        view = NSView()
        preferredContentSize = NSSize(width: 420, height: 520)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCapture()
    }

    private func configureCapture() {
        removeHostedController()
        do {
            let container = try ModelContainerFactory.make(
                inMemory: false,
                cloudKit: true
            )
            self.container = container
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
        } catch {
            host(
                ShareStoreFailureView(
                    onRetry: { [weak self] in self?.configureCapture() },
                    onCancel: { [weak self] in self?.cancelRequest() }
                )
            )
        }
    }

    private var inputProviders: [NSItemProvider] {
        (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []
    }

    private func cancelRequest() {
        let error = NSError(
            domain: "BookmarkShareExtension",
            code: NSUserCancelledError,
            userInfo: [
                NSLocalizedDescriptionKey: "Bookmark capture was cancelled."
            ]
        )
        extensionContext?.cancelRequest(withError: error)
    }

    private func host<Content: View>(_ content: Content) {
        let controller = NSHostingController(rootView: content)
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostedController = controller
    }

    private func removeHostedController() {
        guard let hostedController else { return }
        hostedController.view.removeFromSuperview()
        hostedController.removeFromParent()
        self.hostedController = nil
        container = nil
    }
}
#endif
```

Keep `ShareStoreFailureView` outside both platform conditions so Retry and
Cancel behavior stays identical.

- [ ] **Step 6: Build the unsigned macOS containing app**

Run:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`, with `BookmarkShareExtension.appex` compiled
for macOS and copied into `BookmarkCollections.app`.

- [ ] **Step 7: Build the unsigned iOS containing app**

Run:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`, proving the conditional code and original
iOS extension still compile.

- [ ] **Step 8: Re-run capture-model tests**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests
```

Expected: all capture-model tests pass.

- [ ] **Step 9: Commit the multiplatform extension**

```bash
git add \
  BookmarkCollections.xcodeproj/project.pbxproj \
  BookmarkShareExtension/BookmarkShareExtensionMac.entitlements \
  BookmarkShareExtension/ShareCaptureView.swift \
  BookmarkShareExtension/ShareViewController.swift
git commit -m "feat: add macOS Share extension"
```

---

### Task 3: Verify Signed Embedding, Entitlements, and Regression Suites

**Files:**
- Modify only if verification exposes a concrete defect:
  `BookmarkCollections.xcodeproj/project.pbxproj`,
  `BookmarkShareExtension/BookmarkShareExtensionMac.entitlements`,
  `BookmarkShareExtension/ShareCaptureView.swift`, or
  `BookmarkShareExtension/ShareViewController.swift`

**Interfaces:**
- Consumes: the multiplatform extension product from Task 2.
- Produces: signed macOS and iOS containing apps with embedded, correctly
  entitled Share extensions and passing automated suites.

- [ ] **Step 1: Build the signed macOS app into a deterministic directory**

Run:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/ShareExtensionDerivedData
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Locate and inspect the embedded macOS extension**

Run:

```bash
MAC_APP="build/ShareExtensionDerivedData/Build/Products/Debug/BookmarkCollections.app"
find "$MAC_APP" -name 'BookmarkShareExtension.appex' -print
```

Expected: exactly one path inside the containing app. Assign that printed path
to `MAC_EXTENSION`, then run:

```bash
codesign --verify --deep --strict --verbose=2 "$MAC_APP"
codesign -d --entitlements :- "$MAC_APP"
codesign -d --entitlements :- "$MAC_EXTENSION"
plutil -p "$MAC_EXTENSION/Contents/Info.plist"
```

Expected:

- signature verification succeeds;
- app and extension both contain
  `group.com.loweffortapps.BookmarkCollections`;
- app and extension both contain
  `iCloud.com.loweffortapps.BookmarkCollections`;
- extension contains `com.apple.security.app-sandbox = true`;
- extension contains `com.apple.security.network.client = true`;
- extension point is `com.apple.share-services`; and
- display name is `Save to Tucked`.

- [ ] **Step 3: Confirm macOS registers the extension**

Run:

```bash
open "$MAC_APP"
pluginkit -mAvvv -p com.apple.share-services |
  rg -C 3 'com\\.loweffortapps\\.BookmarkCollections\\.ShareExtension'
```

Expected: the Tucked extension appears as a registered macOS Share service.
If it is absent, inspect `pluginkit -mAvvv` and the signed extension Info.plist
before changing code.

- [ ] **Step 4: Run the native macOS unit suite**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests
```

Expected: all unit tests pass.

- [ ] **Step 5: Run the native macOS UI suite**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsUITests
```

Expected: all UI tests pass with the runner normally signed.

- [ ] **Step 6: Build the signed iOS app and extension**

Run:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'generic/platform=iOS'
```

Expected: `** BUILD SUCCEEDED **`, with the iOS Share extension signed and
embedded. If provisioning requires profile refresh, rerun with
`-allowProvisioningUpdates`; do not alter identifiers.

- [ ] **Step 7: Run iOS simulator capture-model regression tests**

Run:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BookmarkCollectionsTests/ShareCaptureModelTests
```

Expected: all capture-model tests pass. If that named simulator is unavailable,
use `xcrun simctl list devices available` and substitute one installed iPhone;
record the actual destination in verification notes.

- [ ] **Step 8: Commit only concrete verification fixes**

If Steps 1–7 required code or configuration changes, rerun the failed command
and the platform counterpart, then commit only those fixes:

```bash
git add \
  BookmarkCollections.xcodeproj/project.pbxproj \
  BookmarkShareExtension/BookmarkShareExtensionMac.entitlements \
  BookmarkShareExtension/ShareCaptureView.swift \
  BookmarkShareExtension/ShareViewController.swift
git commit -m "fix: correct Share extension platform integration"
```

If no files changed, do not create an empty commit.

---

### Task 4: Perform the Live macOS Share Flow and Update Project Records

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `DECISIONS.md`
- Modify: `TODO.md`
- Modify: `docs/verification/cloudkit-device-matrix.md`

**Interfaces:**
- Consumes: the signed and registered macOS extension from Task 3.
- Produces: human-verified macOS link/image capture and documentation that
  distinguishes observed evidence from remaining release gates.

- [ ] **Step 1: Verify a link share while Tucked is closed**

Quit Tucked. In Safari, open an HTTP/HTTPS page and choose
**Share → Save to Tucked**. In the panel:

1. confirm the URL or metadata preview is visible;
2. choose a non-default collection;
3. turn Favorite on;
4. choose Save; and
5. confirm the panel dismisses.

Open Tucked and verify exactly one bookmark exists for the normalized URL with
the chosen collection and Favorite state. Re-share the same page and verify it
updates the existing record rather than creating an independent duplicate.

- [ ] **Step 2: Verify an image share while Tucked is closed**

Quit Tucked. From Preview, Photos, or Finder's standard Share menu, share one
valid image to **Save to Tucked**. In the panel:

1. confirm the image preview is visible;
2. choose a non-default collection;
3. turn Favorite on;
4. choose Save; and
5. confirm the panel dismisses.

Open Tucked and verify one image bookmark exists with visible image data, a
non-empty title, the chosen collection, and Favorite enabled.

- [ ] **Step 3: Verify failure/cancel behavior without fabricating a save**

Open the macOS Share panel again and choose Cancel. Confirm no item is added.
If an ordinary host can supply unsupported content, confirm the inline error is
visible and Save remains disabled. Do not manufacture a storage failure by
deleting or corrupting the App Group store.

- [ ] **Step 4: Update the product documentation**

Make these precise documentation changes:

- `README.md`: change iOS-only Share Sheet language to iOS and macOS; state
  that links and images can be captured on both platforms.
- `CHANGELOG.md`: add a 2026-07-23 Added entry for macOS Share menus with link,
  text-link, image, Collection, and Favorite parity.
- `DECISIONS.md`: append a 2026-07-23 decision that the existing Share
  extension is multiplatform and supersedes “v1 image capture is iOS-only”;
  explain why one shared target was chosen over separate platform targets.
- `TODO.md`: keep Photos picker, Files importer, and drag-and-drop entries
  deferred; clarify that they are alternate import paths, not missing Share
  Sheet support.
- `docs/verification/cloudkit-device-matrix.md`: record the exact macOS build,
  entitlement, registration, Safari link, and image-host results actually
  observed. Do not mark CloudKit Production, TestFlight, or unrelated pending
  manual checks complete.

- [ ] **Step 5: Validate documentation and review the complete diff**

Run:

```bash
git diff --check
git status --short
git diff -- \
  README.md \
  CHANGELOG.md \
  DECISIONS.md \
  TODO.md \
  docs/verification/cloudkit-device-matrix.md
```

Expected: no whitespace errors, no unrelated changes, and every verification
claim corresponds to evidence from Tasks 2–4.

- [ ] **Step 6: Commit documentation and verified evidence**

```bash
git add \
  README.md \
  CHANGELOG.md \
  DECISIONS.md \
  TODO.md \
  docs/verification/cloudkit-device-matrix.md
git commit -m "docs: record macOS Share extension support"
```

---

### Task 5: Final Verification and Handoff

**Files:**
- Review: all files changed by Tasks 1–4

**Interfaces:**
- Consumes: all prior task deliverables.
- Produces: a clean, evidence-backed implementation ready for branch-finishing
  review without overstating CloudKit release readiness.

- [ ] **Step 1: Run the complete narrowest relevant automated matrix**

Run the macOS unit and UI targets separately:

```bash
xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsTests

xcodebuild test \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS' \
  -only-testing:BookmarkCollectionsUITests
```

Then build both signed containing apps:

```bash
xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'platform=macOS'

xcodebuild build \
  -project BookmarkCollections.xcodeproj \
  -scheme BookmarkCollections \
  -destination 'generic/platform=iOS'
```

Expected: all tests and builds succeed.

- [ ] **Step 2: Review the final diff and commit history**

Run:

```bash
git status --short
git diff HEAD~4 --check
git diff --stat HEAD~4
git log -5 --oneline --decorate
```

Expected: no uncommitted implementation changes; the history contains focused
test, feature, optional integration-fix, and documentation commits. Adjust the
`HEAD~4` review base if the optional integration-fix commit was unnecessary.

- [ ] **Step 3: Report evidence and remaining manual gates**

The handoff must state:

- macOS link Share result and source host;
- macOS image Share result and source host;
- whether Tucked was closed for each capture;
- macOS extension registration result;
- signed macOS and iOS build results;
- macOS unit/UI and iOS capture-test results;
- entitlement identifiers inspected; and
- any still-pending real-device CloudKit Production or TestFlight gates.

Do not claim production CloudKit readiness from these local builds and Share
flows.
