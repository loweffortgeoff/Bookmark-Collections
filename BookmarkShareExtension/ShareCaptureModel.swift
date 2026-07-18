import Combine
import Foundation
import SwiftData
import UniformTypeIdentifiers

struct ShareCapture: Equatable {
    let urlString: String
    var suggestedTitle: String?
    var faviconData: Data?
    var previewImageData: Data?
}

enum ShareCaptureState: Equatable {
    case idle
    case loading
    case ready
    case saving
    case saved
    case failed(String)
}

@MainActor
final class ShareCaptureModel: ObservableObject {
    typealias SaveAction = @MainActor (ShareCapture, UUID?, Bool) throws -> SaveResult

    @Published private(set) var state: ShareCaptureState = .idle
    @Published private(set) var capture: ShareCapture?
    let collections: [BookmarkCollection]

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
            let result = try BookmarkRepository(context: context).save(
                url: capture.urlString,
                collection: collection,
                favorite: favorite
            )
            let bookmark = switch result {
            case let .created(bookmark), let .updated(bookmark), let .restored(bookmark): bookmark
            }
            if let title = capture.suggestedTitle, !title.isEmpty {
                bookmark.title = title
            }
            bookmark.faviconData = capture.faviconData
            bookmark.previewImageData = capture.previewImageData
            if capture.suggestedTitle != nil || capture.faviconData != nil || capture.previewImageData != nil {
                bookmark.metadataState = .ready
                bookmark.lastMetadataRefreshAt = Date()
                try? context.save()
            }
            return result
        }
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
        state = .loading
        capture = nil

        let directURL = await firstURL(from: providers)
        let loaded: ShareCapture?
        if let directURL {
            loaded = directURL
        } else {
            loaded = await firstURL(inTextFrom: providers)
        }
        if let loaded {
            capture = loaded
            state = .ready
            fetchMetadata(for: loaded)
        } else {
            state = .failed("Share a web link that begins with http:// or https://.")
        }
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
        } catch {
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

        Task { [weak self] in
            guard let metadata = try? await metadataProvider.metadata(for: url),
                  var capture = self?.capture,
                  capture.urlString == loaded.urlString else { return }
            capture.suggestedTitle = metadata.title ?? capture.suggestedTitle
            capture.faviconData = metadata.faviconData
            capture.previewImageData = metadata.previewImageData
            self?.capture = capture
        }
    }
}
