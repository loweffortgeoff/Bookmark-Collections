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

#endif
