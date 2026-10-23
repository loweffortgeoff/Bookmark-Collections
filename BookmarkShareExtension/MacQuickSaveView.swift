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
/// Safari window dimmed and no message was drawn. An offscreen `ImageRenderer`
/// draw of the `ContentUnavailableView` version was empty and a plain stack
/// drew normally, but `ImageRenderer` has its own limits. Whether this changes
/// what ShareKit shows has not been confirmed on a Mac.
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
