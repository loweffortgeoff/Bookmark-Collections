import SwiftUI

#if os(macOS)
struct MacQuickSaveView: View {
    @ObservedObject var model: ShareCaptureModel
    let providers: [NSItemProvider]
    let onCancel: () -> Void

    var body: some View {
        Group {
            if case let .failed(message) = model.state {
                MacShareFailureView(
                    title: "Couldn’t Save to Tucked",
                    message: message,
                    onRetry: {
                        Task {
                            await model.quickSave(from: providers)
                        }
                    },
                    onCancel: onCancel
                )
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Saving to Tucked…")
                }
            }
        }
        .frame(minWidth: 360, minHeight: 200)
        .task {
            guard model.state == .idle else { return }
            await model.quickSave(from: providers)
        }
    }
}

/// A plain stack, not `ContentUnavailableView`. On a failed Mac share the
/// Safari window dimmed and no message was drawn. An offscreen render of the
/// `ContentUnavailableView` version also drew nothing, while a plain stack
/// drew normally.
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
