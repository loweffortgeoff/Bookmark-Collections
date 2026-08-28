import Foundation
import SwiftData

/// Reads image files chosen from a file picker and saves them through the
/// same downsample-and-store path the Share extension uses.
@MainActor
struct ImageImportService {
    let context: ModelContext

    /// One unreadable file must not cost the rest of the selection, so a
    /// failure is recorded and the batch continues.
    func importImages(at urls: [URL]) throws -> ImportSummary {
        let repository = BookmarkRepository(context: context)
        var summary = ImportSummary()

        for url in urls {
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url), ImageDownsampler.isValidImage(data) else {
                summary.failedLines.append(url.lastPathComponent)
                continue
            }

            do {
                try repository.saveImage(
                    data: ImageDownsampler.downsample(data, maximumPixelSize: 1_200),
                    title: url.deletingPathExtension().lastPathComponent
                )
                summary.newCount += 1
            } catch {
                summary.failedLines.append(url.lastPathComponent)
            }
        }

        return summary
    }
}
