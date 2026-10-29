import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageDownsampler {
    static func isValidImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 0
    }

    /// How a downsampled image is re-encoded for storage.
    enum Encoding {
        /// Lossless. Used for images the user saved, which share and export
        /// hand back byte for byte, and which are often screenshots of text.
        case png
        /// JPEG for opaque images, PNG when the image has an alpha channel.
        /// Used for fetched link previews, which are usually photos.
        case jpegUnlessTransparent
    }

    static let jpegQuality = 0.8

    static func downsample(
        _ data: Data,
        maximumPixelSize: Int,
        encoding: Encoding = .png
    ) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return data
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return data
        }

        let usesJPEG = encoding == .jpegUnlessTransparent && !hasAlpha(image)
        let type = usesJPEG ? UTType.jpeg : UTType.png
        let properties: [CFString: Any] = usesJPEG
            ? [kCGImageDestinationLossyCompressionQuality: jpegQuality]
            : [:]

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            type.identifier as CFString,
            1,
            nil
        ) else {
            return data
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return data }
        return output as Data
    }

    private static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            false
        default:
            true
        }
    }
}
