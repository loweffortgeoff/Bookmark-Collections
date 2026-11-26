import CoreGraphics
import XCTest
@testable import BookmarkCollections

final class ImageViewerTransformTests: XCTestCase {
    func testAt1xZoomMaxOffsetIsZeroAndProposedOffsetClampsToZero() {
        let offset = ImageViewerTransform.clampedOffset(
            CGSize(width: 80, height: -40),
            imageSize: CGSize(width: 640, height: 480),
            in: CGSize(width: 400, height: 800),
            scale: 1
        )
        XCTAssertEqual(offset, .zero)
    }

    func testZoomedLandscapeImageClampsToActualScaledOverflow() {
        let image = CGSize(width: 800, height: 400)
        let viewport = CGSize(width: 400, height: 800)

        XCTAssertEqual(ImageViewerTransform.fittedSize(imageSize: image, in: viewport), CGSize(width: 400, height: 200))
        XCTAssertEqual(ImageViewerTransform.maxOffset(imageSize: image, in: viewport, scale: 2), CGSize(width: 200, height: 0))
        XCTAssertEqual(ImageViewerTransform.maxOffset(imageSize: image, in: viewport, scale: 5), CGSize(width: 800, height: 100))
    }

    func testZoomedPortraitImageInWideViewportClampsHorizontallyToZeroUntilOverflow() {
        let image = CGSize(width: 400, height: 800)
        let viewport = CGSize(width: 800, height: 400)

        XCTAssertEqual(ImageViewerTransform.fittedSize(imageSize: image, in: viewport), CGSize(width: 200, height: 400))
        XCTAssertEqual(ImageViewerTransform.maxOffset(imageSize: image, in: viewport, scale: 2), CGSize(width: 0, height: 200))
        XCTAssertEqual(
            ImageViewerTransform.clampedOffset(CGSize(width: -500, height: -500), imageSize: image, in: viewport, scale: 2),
            CGSize(width: 0, height: -200)
        )
    }

    func testClampedScaleHonors1xTo8xRange() {
        XCTAssertEqual(ImageViewerTransform.clampedScale(0.5), 1)
        XCTAssertEqual(ImageViewerTransform.clampedScale(3), 3)
        XCTAssertEqual(ImageViewerTransform.clampedScale(12), 8)
    }

    func testViewportResizeReclampsExistingOffset() {
        let image = CGSize(width: 400, height: 400)
        let offset = CGSize(width: 200, height: 200)
        // Valid at 400×400 and 2×: the image overflows by 200 on each side.
        XCTAssertEqual(
            ImageViewerTransform.clampedOffset(offset, imageSize: image, in: CGSize(width: 400, height: 400), scale: 2),
            offset
        )
        // A wider window leaves no horizontal overflow at 2×.
        XCTAssertEqual(
            ImageViewerTransform.clampedOffset(offset, imageSize: image, in: CGSize(width: 900, height: 400), scale: 2),
            CGSize(width: 0, height: 200)
        )
    }

    func testZeroImageOrViewportSizeReturnsZeroOffset() {
        let proposed = CGSize(width: 50, height: 50)
        XCTAssertEqual(ImageViewerTransform.fittedSize(imageSize: .zero, in: CGSize(width: 400, height: 400)), .zero)
        XCTAssertEqual(ImageViewerTransform.clampedOffset(proposed, imageSize: .zero, in: CGSize(width: 400, height: 400), scale: 4), .zero)
        XCTAssertEqual(ImageViewerTransform.clampedOffset(proposed, imageSize: CGSize(width: 400, height: 400), in: .zero, scale: 4), .zero)
    }
}
