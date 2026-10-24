import SwiftUI

#if os(macOS)
struct MacQuickSaveView: View {
    @ObservedObject var model: ShareCaptureModel
    let providers: [NSItemProvider]
    let onCancel: () -> Void
    let openContainingApp: () async throws -> Void

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
                    onCancel: onCancel,
                    onOpenTucked: model.failureReason == .limitReached ? {
                        Task { await model.openContainingApp(using: openContainingApp, onCancel: onCancel) }
                    } : nil
                )
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Saving to Tucked…")
                }
            }
        }
        .frame(minWidth: 360, minHeight: 240)
        .task {
            guard model.state == .idle else { return }
            await model.quickSave(from: providers)
        }
    }
}

#endif
