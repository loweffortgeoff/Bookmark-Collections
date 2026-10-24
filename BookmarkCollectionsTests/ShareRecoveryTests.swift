import XCTest
@testable import BookmarkCollections

#if os(macOS)
@MainActor
final class ShareRecoveryTests: XCTestCase {
    func testLimitHasTypedReasonAndSuccessfulOpenCancelsWithoutSaving() async {
        var completed = 0
        var cancelled = 0
        var opened = 0
        let model = ShareCaptureModel(collections: [], saveAction: { _, _, _ in
            throw BookmarkRepository.LimitError.limitReached
        }, onComplete: { completed += 1 })
        await model.quickSave(from: [NSItemProvider(object: NSURL(string: "https://example.com/limit")!)])
        XCTAssertEqual(model.failureReason, .limitReached)
        await model.openContainingApp(using: { opened += 1 }, onCancel: { cancelled += 1 })
        XCTAssertEqual(opened, 1)
        XCTAssertEqual(cancelled, 1)
        XCTAssertEqual(completed, 0)
    }

    func testFailedOpenKeepsLimitSurfaceAndDoesNotCancel() async {
        var cancelled = false
        let model = ShareCaptureModel(collections: [], saveAction: { _, _, _ in
            throw BookmarkRepository.LimitError.limitReached
        }, onComplete: { XCTFail("An unsaved Share must not complete") })
        await model.quickSave(from: [NSItemProvider(object: NSURL(string: "https://example.com/limit")!)])
        await model.openContainingApp(using: { throw CocoaError(.fileNoSuchFile) }, onCancel: { cancelled = true })
        XCTAssertFalse(cancelled)
        XCTAssertEqual(model.failureReason, .limitReached)
        guard case let .failed(message) = model.state else { return XCTFail("Failure must stay visible") }
        XCTAssertTrue(message.contains("Applications"))
    }

    func testStorageFailureDoesNotOpenApplication() async {
        let model = ShareCaptureModel(collections: [], saveAction: { _, _, _ in
            throw CocoaError(.fileWriteNoPermission)
        }, onComplete: {})
        await model.quickSave(from: [NSItemProvider(object: NSURL(string: "https://example.com/store")!)])
        XCTAssertEqual(model.failureReason, .saveFailed)
        await model.openContainingApp(using: { XCTFail("Storage failure keeps Retry") }, onCancel: { XCTFail("Do not cancel") })
    }
}
#endif
