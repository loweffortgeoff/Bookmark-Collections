import SwiftUI

#if os(macOS)
/// A plain stack sized to fit the fixed 360 by 200 share view.
/// `ContentUnavailableView` would probably need more height.
struct MacShareFailureView: View {
    let title: String
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 200)
    }
}
#endif
