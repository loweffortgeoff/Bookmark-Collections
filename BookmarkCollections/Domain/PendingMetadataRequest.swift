import SwiftData

/// A URL edit restarts enrichment even when the stored record is unchanged.
struct PendingMetadataRequest: Equatable {
    let id: PersistentIdentifier
    let urlString: String
}
