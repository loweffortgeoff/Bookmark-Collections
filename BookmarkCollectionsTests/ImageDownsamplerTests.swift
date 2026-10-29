import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import BookmarkCollections

final class ImageDownsamplerTests: XCTestCase {
    func testSavedImagesStayPNG() throws {
        let data = try Self.imageData(alpha: .noneSkipLast, type: .jpeg)

        let output = ImageDownsampler.downsample(data, maximumPixelSize: 1_200)

        XCTAssertEqual(try Self.type(of: output), UTType.png.identifier)
    }

    func testOpaqueLinkPreviewsBecomeJPEG() throws {
        let data = try Self.imageData(alpha: .noneSkipLast, type: .jpeg)

        let output = ImageDownsampler.downsample(
            data,
            maximumPixelSize: 1_200,
            encoding: .jpegUnlessTransparent
        )

        XCTAssertEqual(try Self.type(of: output), UTType.jpeg.identifier)
    }

    func testTransparentLinkPreviewsStayPNG() throws {
        let data = try Self.imageData(alpha: .premultipliedLast, type: .png)

        let output = ImageDownsampler.downsample(
            data,
            maximumPixelSize: 1_200,
            encoding: .jpegUnlessTransparent
        )

        XCTAssertEqual(try Self.type(of: output), UTType.png.identifier)
    }

    func testLinkPreviewsAreStillDownsampled() throws {
        let data = try Self.imageData(alpha: .noneSkipLast, type: .jpeg, width: 2_400, height: 1_200)

        let output = ImageDownsampler.downsample(
            data,
            maximumPixelSize: 1_200,
            encoding: .jpegUnlessTransparent
        )

        let source = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(max(image.width, image.height), 1_200)
    }

    private static func type(of data: Data) throws -> String? {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return CGImageSourceGetType(source) as String?
    }

    private static func imageData(
        alpha: CGImageAlphaInfo,
        type: UTType,
        width: Int = 64,
        height: Int = 48
    ) throws -> Data {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: alpha.rawValue
            )
        )
        context.setFillColor(red: 0.4, green: 0.6, blue: 0.8, alpha: alpha == .premultipliedLast ? 0.5 : 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())

        let output = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
