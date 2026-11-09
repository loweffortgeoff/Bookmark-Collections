import SwiftUI

struct ShareCaptureView: View {
    @ObservedObject var model: ShareCaptureModel
    let items: [NSExtensionItem]
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            #if os(macOS)
            VStack(spacing: 0) {
                captureForm
                Divider()
                HStack {
                    Button("Cancel", action: onCancel)
                    Spacer()
                    if !isLimitReached {
                        Button(saveButtonTitle) {
                            model.save(collectionID: model.selectedCollectionID, favorite: model.isFavorite)
                        }
                        .disabled(model.capture == nil || model.state == .saving || model.state == .saved)
                    }
                }
                .padding()
            }
            #elseif os(iOS)
            captureForm
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                if !isLimitReached {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveButtonTitle) {
                            model.save(collectionID: model.selectedCollectionID, favorite: model.isFavorite)
                        }
                        .disabled(model.capture == nil || model.state == .saving || model.state == .saved)
                    }
                }
            }
            #endif
        }
        .task {
            guard model.state == .idle else { return }
            await model.load(items: items)
        }
    }

    private var captureForm: some View {
        Form {
            captureSection
            if model.capture != nil {
                Picker("Collection", selection: $model.selectedCollectionID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(model.collections, id: \.persistentModelID) { collection in
                        Text(collection.name).tag(collection.id as UUID?)
                    }
                }
                Toggle("Favorite", isOn: $model.isFavorite)
            }
            if case let .failed(message) = model.state {
                Section {
                    if isLimitReached {
                        Label(message, systemImage: "lock")
                    } else {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(model.capture?.kind == .text ? Text("Save Snippet") : Text("Save Bookmark"))
    }

    @ViewBuilder
    private var captureSection: some View {
        switch model.state {
        case .idle, .loading:
            HStack {
                ProgressView()
                Text("Loading shared item…")
            }
        case .saving:
            HStack {
                ProgressView()
                Text("Saving…")
            }
        default:
            if let capture = model.capture {
                ShareCapturePreview(
                    kind: capture.kind,
                    snippetBody: capture.snippetBody,
                    urlString: capture.urlString,
                    suggestedTitle: capture.suggestedTitle,
                    previewImageData: capture.previewImageData
                )
            }
        }
    }

    private var isLimitReached: Bool {
        model.failureReason == .limitReached
    }

    private var saveButtonTitle: String {
        if case .failed = model.state, model.capture != nil {
            return "Retry"
        }
        return "Save"
    }
}
