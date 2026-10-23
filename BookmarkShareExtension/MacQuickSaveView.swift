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
        // ShareKit draws only what the view paints. Without a background the
        // text sits directly on the dimmed Safari window.
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            guard model.state == .idle else { return }
            await model.quickSave(from: providers)
        }
    }
}

/// A plain stack. It was seen drawing in Safari's share panel once the
/// extension view had a real size (see `ShareViewController.loadView`).
/// `ContentUnavailableView` was never tried at that size.
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
