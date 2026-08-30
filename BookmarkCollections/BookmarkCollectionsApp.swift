import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@main
struct BookmarkCollectionsApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @State private var storefront = Storefront()
    private let container: ModelContainer

    init() {
        let runtime = AppRuntimeConfiguration()
        BookmarkLimit.freeBookmarkLimitOverride = runtime.freeBookmarkLimitOverride
        container = try! ModelContainerFactory.make(
            inMemory: runtime.usesInMemoryStore,
            cloudKit: runtime.usesCloudKit
        )
        if runtime.isUITesting {
            Self.seedUITestLibrary(in: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryRootView()
                .environment(storefront)
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    try? BookmarkRepository(context: container.mainContext).reconcileDuplicates()
                    let enricher = MetadataEnricher(
                        context: container.mainContext,
                        provider: LinkPresentationMetadataProvider()
                    )
                    try? await enricher.enrichPending(limit: 20)
                }
        }
        .modelContainer(container)
        .commands {
            #if os(macOS)
            BookmarkCommands()
            #else
            EmptyCommands()
            #endif
        }
    }

    @MainActor
    private static func seedUITestLibrary(in context: ModelContext) {
        let collection = BookmarkCollection(name: "Reading", sortPosition: 0)
        let active = Bookmark(
            urlString: "https://example.com/seeded-active",
            normalizedURLString: "https://example.com/seeded-active"
        )
        active.title = "Seeded Active"
        active.domain = "example.com"
        active.collection = collection
        active.isFavorite = true
        active.metadataState = .ready
        let deleted = Bookmark(
            urlString: "https://example.com/seeded-deleted",
            normalizedURLString: "https://example.com/seeded-deleted"
        )
        deleted.title = "Seeded Deleted"
        deleted.domain = "example.com"
        deleted.deletedAt = Date()
        deleted.metadataState = .ready
        context.insert(collection)
        context.insert(active)
        context.insert(deleted)
        for preview in seededPreviewBookmarks() {
            context.insert(preview)
        }
        let image = Bookmark(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            urlString: "",
            normalizedURLString: ""
        )
        image.kind = .image
        image.title = "Seeded Image"
        image.metadataState = .ready
        image.previewImageData = solidPreviewData(width: 640, height: 480, red: 0.85, green: 0.60, blue: 0.20)
        context.insert(image)
        let snippet = Bookmark(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            urlString: "",
            normalizedURLString: ""
        )
        snippet.kind = .text
        snippet.title = "Seeded Snippet"
        snippet.snippetBody = "The part of the article worth keeping, saved as text."
        snippet.metadataState = .ready
        context.insert(snippet)
        try? context.save()
    }

    /// Bookmarks whose preview images span portrait, wide, and square aspect
    /// ratios with mixed title lengths — the grid must render them at uniform
    /// card size.
    @MainActor
    private static func seededPreviewBookmarks() -> [Bookmark] {
        let variants: [(slug: String, title: String, width: CGFloat, height: CGFloat, tint: (Double, Double, Double))] = [
            ("seeded-portrait", "Portrait Preview With a Deliberately Long Two Line Title", 600, 900, (0.75, 0.30, 0.30)),
            ("seeded-wide", "Wide", 1200, 400, (0.30, 0.55, 0.75)),
            ("seeded-square", "Square Preview", 500, 500, (0.35, 0.65, 0.40)),
            ("seeded-landscape", "Landscape 16:9 Preview", 800, 450, (0.60, 0.45, 0.70))
        ]
        return variants.map { variant in
            let bookmark = Bookmark(
                urlString: "https://example.com/\(variant.slug)",
                normalizedURLString: "https://example.com/\(variant.slug)"
            )
            bookmark.title = variant.title
            bookmark.domain = "example.com"
            bookmark.metadataState = .ready
            bookmark.previewImageData = solidPreviewData(
                width: variant.width,
                height: variant.height,
                red: variant.tint.0,
                green: variant.tint.1,
                blue: variant.tint.2
            )
            return bookmark
        }
    }

    private static func solidPreviewData(width: CGFloat, height: CGFloat, red: Double, green: Double, blue: Double) -> Data? {
        #if os(macOS)
        let image = NSImage(size: .init(width: width, height: height), flipped: false) { rect in
            NSColor(red: red, green: green, blue: blue, alpha: 1).setFill()
            rect.fill()
            return true
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
        #else
        let renderer = UIGraphicsImageRenderer(size: .init(width: width, height: height))
        return renderer.pngData { context in
            UIColor(red: red, green: green, blue: blue, alpha: 1).setFill()
            context.fill(.init(x: 0, y: 0, width: width, height: height))
        }
        #endif
    }
}

struct AppRuntimeConfiguration {
    let usesInMemoryStore: Bool
    let usesCloudKit: Bool
    let isUITesting: Bool
    let freeBookmarkLimitOverride: Int?

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        isUITesting = arguments.contains("-ui-testing")
        usesInMemoryStore = environment["XCTestConfigurationFilePath"] != nil || isUITesting
        usesCloudKit = !usesInMemoryStore
        freeBookmarkLimitOverride = Self.parseFreeLimit(from: arguments)
    }

    /// Reads `-free-limit N`. Ignores a missing, non-numeric, or negative value.
    private static func parseFreeLimit(from arguments: [String]) -> Int? {
        guard let flag = arguments.firstIndex(of: "-free-limit") else { return nil }
        let valueIndex = arguments.index(after: flag)
        guard valueIndex < arguments.endIndex,
              let value = Int(arguments[valueIndex]),
              value >= 0
        else { return nil }
        return value
    }
}
