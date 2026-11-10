import SwiftData
import SwiftUI

struct LibraryContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        LibraryRootView()
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                let repository = BookmarkRepository(context: context)
                try? repository.reconcileDuplicates()
                _ = try? repository.purgeExpiredDeleted()
                let enricher = MetadataEnricher(
                    context: context,
                    provider: LinkPresentationMetadataProvider()
                )
                try? await enricher.enrichPending(limit: 20, includePending: false)
            }
    }
}
