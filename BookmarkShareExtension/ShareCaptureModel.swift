import Combine
import Foundation
import OSLog
import SwiftData
import UniformTypeIdentifiers

private let shareSaveLogger = Logger(
    subsystem: "com.loweffortapps.BookmarkCollections",
    category: "ShareSave"
)

struct ShareCapture: Equatable {
    var kind: Bookmark.Kind = .link
    let urlString: String
    var suggestedTitle: String?
    var faviconData: Data?
    var previewImageData: Data?
    var metadataWasFetched = false
    var preserveOrganization = false
}

enum ShareCaptureState: Equatable {
    case idle
    case loading
    case ready
    case saving
    case saved
    case failed(String)
}

enum ShareCaptureError: Error {
    case missingImageData
}

@MainActor
final class ShareCaptureModel: ObservableObject {
    typealias SaveAction = @MainActor (ShareCapture, UUID?, Bool) throws -> SaveResult

    @Published private(set) var state: ShareCaptureState = .idle
    @Published private(set) var capture: ShareCapture?
    let collections: [BookmarkCollection]
    @Published var selectedCollectionID: UUID?
    @Published var isFavorite = false

    private var lookup: ((String) throws -> Bookmark?)?
    private var loadID = UUID()
    private let saveAction: SaveAction
    private let metadataProvider: (any MetadataProviding)?
    private let onComplete: () -> Void

    init(
        context: ModelContext,
        metadataProvider: (any MetadataProviding)? = nil,
        onComplete: @escaping () -> Void
    ) {
        collections = (try? context.fetch(
            FetchDescriptor<BookmarkCollection>(sortBy: [SortDescriptor(\BookmarkCollection.sortPosition)])
        )) ?? []
        saveAction = { capture, collectionID, favorite in
            let collection = try context.fetch(FetchDescriptor<BookmarkCollection>())
                .first(where: { $0.id == collectionID })
            if capture.kind == .image {
                guard let data = capture.previewImageData else {
                    throw ShareCaptureError.missingImageData
                }
                let title: String
                if let suggested = capture.suggestedTitle, !suggested.isEmpty {
                    title = suggested
                } else {
                    title = "Image — \(Date().formatted(date: .abbreviated, time: .omitted))"
                }
                let bookmark = try BookmarkRepository(context: context).saveImage(
                    data: data,
                    title: title,
                    collection: collection,
                    favorite: favorite
                )
                return .created(bookmark)
            }
            return try BookmarkRepository(context: context).saveSharedLink(
                url: capture.urlString, collection: collection, favorite: favorite,
                preserveOrganization: capture.preserveOrganization,
                suggestedTitle: capture.suggestedTitle,
                faviconData: capture.faviconData,
                previewImageData: capture.previewImageData,
                metadataWasFetched: capture.metadataWasFetched
            )
        }
        lookup = { try BookmarkRepository(context: context).sharedLinkMatch(url: $0) }
        self.metadataProvider = metadataProvider
        self.onComplete = onComplete
    }

    init(
        collections: [BookmarkCollection],
        saveAction: @escaping SaveAction,
        metadataProvider: (any MetadataProviding)? = nil,
        onComplete: @escaping () -> Void
    ) {
        self.collections = collections
        self.saveAction = saveAction
        self.metadataProvider = metadataProvider
        self.onComplete = onComplete
    }

    func load(from providers: [NSItemProvider]) async {
        let requestID = UUID()
        loadID = requestID
        state = .loading
        capture = nil
        selectedCollectionID = nil
        isFavorite = false

        let directURL = await firstURL(from: providers)
        let loaded: ShareCapture?
        if let directURL {
            loaded = directURL
        } else if let textURL = await firstURL(inTextFrom: providers) {
            loaded = textURL
        } else {
            loaded = await firstImage(from: providers)
        }
        guard loadID == requestID else { return }
        if let loaded {
            do {
                if loaded.kind == .link, let existing = try lookup?(loaded.urlString) {
                    selectedCollectionID = existing.collection?.id
                    isFavorite = existing.isFavorite
                }
            } catch {
                state = .failed("The bookmark could not be loaded. Check storage access and try again.")
                return
            }
            capture = loaded
            state = .ready
            if loaded.kind == .link {
                fetchMetadata(for: loaded)
            }
        } else {
            let types = providers.flatMap(\.registeredTypeIdentifiers).joined(separator: ", ")
            shareSaveLogger.notice("Nothing to save in the shared item. Types: \(types, privacy: .public)")
            state = .failed("Share a web link or an image.")
        }
    }

    func quickSave(from providers: [NSItemProvider]) async {
        await load(from: providers)
        guard state == .ready else { return }
        capture?.preserveOrganization = true
        save(collectionID: nil, favorite: false)
    }

    func save(collectionID: UUID?, favorite: Bool) {
        guard let capture else {
            state = .failed("Load a valid web link before saving.")
            return
        }

        state = .saving
        do {
            _ = try saveAction(capture, collectionID, favorite)
            state = .saved
            onComplete()
        } catch let error as BookmarkRepository.LimitError where error == .limitReached {
            shareSaveLogger.notice("Save blocked by the free bookmark limit")
            state = .failed("You’ve saved 10 bookmarks free. Open Tucked to unlock Tucked for Life.")
        } catch {
            shareSaveLogger.error("""
                Save failed: \(ShareStorageDiagnostics.logSummary(for: error), privacy: .public) \
                detail: \(String(reflecting: error), privacy: .private)
                """)
            state = .failed("The bookmark wasn’t saved. Check storage access and try again.")
        }
    }

    private func firstURL(from providers: [NSItemProvider]) async -> ShareCapture? {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            guard let value = await urlString(from: provider),
                  let normalized = try? NormalizedURL(value) else {
                continue
            }
            return ShareCapture(
                urlString: normalized.url.absoluteString,
                suggestedTitle: provider.suggestedName,
                faviconData: nil,
                previewImageData: nil
            )
        }
        return nil
    }

    private func urlString(from provider: NSItemProvider) async -> String? {
        if provider.canLoadObject(ofClass: NSURL.self),
           let url = await withCheckedContinuation({ (continuation: CheckedContinuation<URL?, Never>) in
               provider.loadObject(ofClass: NSURL.self) { object, _ in
                   continuation.resume(returning: (object as? NSURL).map { $0 as URL })
               }
           }) {
            return url.absoluteString
        }
        if let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
           let value = urlString(from: item) {
            return value
        }
        if let data = await withCheckedContinuation({ continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.url.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private func firstURL(inTextFrom providers: [NSItemProvider]) async -> ShareCapture? {
        let textTypes = [UTType.plainText.identifier, UTType.text.identifier]
        for provider in providers {
            for typeIdentifier in textTypes where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                guard let item = try? await provider.loadItem(forTypeIdentifier: typeIdentifier),
                      let text = text(from: item),
                      let value = firstValidURL(in: text),
                      let normalized = try? NormalizedURL(value) else {
                    continue
                }
                return ShareCapture(
                    urlString: normalized.url.absoluteString,
                    suggestedTitle: provider.suggestedName,
                    faviconData: nil,
                    previewImageData: nil
                )
            }
        }
        return nil
    }

    private func firstImage(from providers: [NSItemProvider]) async -> ShareCapture? {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let data: Data? = await withCheckedContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    continuation.resume(returning: data)
                }
            }
            guard let data, ImageDownsampler.isValidImage(data) else { continue }
            return ShareCapture(
                kind: .image,
                urlString: "",
                suggestedTitle: provider.suggestedName,
                faviconData: nil,
                previewImageData: ImageDownsampler.downsample(data, maximumPixelSize: 1_200)
            )
        }
        return nil
    }

    private func urlString(from item: NSSecureCoding) -> String? {
        if let url = item as? URL { return url.absoluteString }
        if let url = item as? NSURL { return url.absoluteString }
        if let string = item as? String { return string }
        if let string = item as? NSString { return string as String }
        if let data = item as? Data { return String(data: data, encoding: .utf8) }
        return nil
    }

    private func text(from item: NSSecureCoding) -> String? {
        if let string = item as? String { return string }
        if let string = item as? NSString { return string as String }
        if let data = item as? Data { return String(data: data, encoding: .utf8) }
        return nil
    }

    private func firstValidURL(in text: String) -> String? {
        let trimSet = CharacterSet(charactersIn: "<>()[]{}\"'.,;:!?")
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: trimSet) }
            .first { (try? NormalizedURL($0)) != nil }
    }

    private func fetchMetadata(for loaded: ShareCapture) {
        guard let metadataProvider,
              let url = URL(string: loaded.urlString) else { return }

        let requestID = loadID
        Task { [weak self] in
            guard let metadata = try? await metadataProvider.metadata(for: url),
                  self?.loadID == requestID,
                  var capture = self?.capture,
                  capture.urlString == loaded.urlString else { return }
            capture.metadataWasFetched = true
            capture.suggestedTitle = metadata.title ?? capture.suggestedTitle
            capture.faviconData = metadata.faviconData
            capture.previewImageData = metadata.previewImageData
            self?.capture = capture
        }
    }
}
