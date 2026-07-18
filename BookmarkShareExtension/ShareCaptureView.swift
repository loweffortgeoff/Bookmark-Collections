import SwiftUI
import UIKit

struct ShareCaptureView: View {
    @ObservedObject var model: ShareCaptureModel
    let providers: [NSItemProvider]
    let onCancel: () -> Void

    @State private var selectedCollectionID: UUID?
    @State private var isFavorite = false

    var body: some View {
        NavigationStack {
            Form {
                captureSection
                if model.capture != nil {
                    Picker("Collection", selection: $selectedCollectionID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(model.collections) { collection in
                            Text(collection.name).tag(collection.id as UUID?)
                        }
                    }
                    Toggle("Favorite", isOn: $isFavorite)
                }
                if case let .failed(message) = model.state {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Save Bookmark")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveButtonTitle) {
                        model.save(collectionID: selectedCollectionID, favorite: isFavorite)
                    }
                    .disabled(model.capture == nil || model.state == .saving || model.state == .saved)
                }
            }
        }
        .task {
            guard model.state == .idle else { return }
            await model.load(from: providers)
        }
    }

    @ViewBuilder
    private var captureSection: some View {
        switch model.state {
        case .idle, .loading:
            HStack {
                ProgressView()
                Text("Loading shared link…")
            }
        case .saving:
            HStack {
                ProgressView()
                Text("Saving…")
            }
        default:
            if let capture = model.capture {
                Section("Link") {
                    if let previewData = capture.previewImageData,
                       let preview = UIImage(data: previewData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityHidden(true)
                    }
                    if let title = capture.suggestedTitle, !title.isEmpty {
                        LabeledContent("Title", value: title)
                    }
                    Text(capture.urlString)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var saveButtonTitle: String {
        if case .failed = model.state, model.capture != nil {
            return "Retry"
        }
        return "Save"
    }
}
