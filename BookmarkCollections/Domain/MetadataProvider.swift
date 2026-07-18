import Foundation
import ImageIO
@preconcurrency import LinkPresentation
import UniformTypeIdentifiers

struct LinkMetadata: Sendable {
    let title: String?
    let domain: String
    let faviconData: Data?
    let previewImageData: Data?

    init(
        title: String? = nil,
        domain: String,
        faviconData: Data? = nil,
        previewImageData: Data? = nil
    ) {
        self.title = title
        self.domain = domain
        self.faviconData = faviconData
        self.previewImageData = previewImageData
    }
}

protocol MetadataProviding: Sendable {
    func metadata(for url: URL) async throws -> LinkMetadata
}

actor LinkPresentationMetadataProvider: MetadataProviding {
    func metadata(for url: URL) async throws -> LinkMetadata {
        let metadata = try await fetchMetadata(for: url)
        let favicon = await imageData(from: metadata.iconProvider)
        let preview = await imageData(from: metadata.imageProvider)

        return LinkMetadata(
            title: metadata.title,
            domain: metadata.originalURL?.host?.lowercased() ?? url.host?.lowercased() ?? "",
            faviconData: favicon,
            previewImageData: preview
        )
    }

    private func fetchMetadata(for url: URL) async throws -> LPLinkMetadata {
        let provider = LPMetadataProvider()
        return try await provider.startFetchingMetadata(for: url)
    }

    private func imageData(from provider: NSItemProvider?) async -> Data? {
        guard let provider,
              provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            return nil
        }

        let data: Data? = await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data else { return nil }
        return downsample(data, maximumPixelSize: 1_200)
    }

    private func downsample(_ data: Data, maximumPixelSize: Int) -> Data {
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

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return data
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return data }
        return output as Data
    }
}
