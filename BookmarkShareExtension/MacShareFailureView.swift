import SwiftUI

#if os(macOS)
struct MacShareFailureView: View {
    let title: String
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void
    var onOpenTucked: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 12) {
                    Label(title, systemImage: "exclamationmark.triangle")
                        .font(.headline)
                    Text(message)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { actions }
                VStack(spacing: 12) { actions }
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 240)
    }

    @ViewBuilder
    private var actions: some View {
        Button("Cancel", action: onCancel)
        if let onOpenTucked {
            Button("Open Tucked", action: onOpenTucked)
                .buttonStyle(.borderedProminent)
        } else {
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
    }
}
#endif
