import SwiftUI

struct LibraryStoreFailureView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Tucked Couldn’t Open Your Library", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Restart your device. If this continues, contact support.")
        } actions: {
            Link(AboutLink.support.title, destination: AboutLink.support.url)
                .accessibilityIdentifier("library.storeFailure.support")
        }
        .accessibilityIdentifier("library.storeFailure")
    }
}
