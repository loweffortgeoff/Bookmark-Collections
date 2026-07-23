import SwiftUI

#if os(iOS)
import UIKit
private typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
private typealias PlatformImage = NSImage
#endif

struct ShareCaptureView: View {
    @ObservedObject var model: ShareCaptureModel
    let providers: [NSItemProvider]
    let onCancel: () -> Void

    @State private var selectedCollectionID: UUID?
    @State private var isFavorite = false

    var body: some View {
        NavigationStack {
            #if os(macOS)
            VStack(spacing: 0) {
                captureForm
                Divider()
                HStack {
                    Button("Cancel", action: onCancel)
                    Spacer()
                    Button(saveButtonTitle) {
                        model.save(collectionID: selectedCollectionID, favorite: isFavorite)
                    }
                    .disabled(model.capture == nil || model.state == .saving || model.state == .saved)
                }
                .padding()
            }
            #elseif os(iOS)
            captureForm
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
            #endif
        }
        .task {
            guard model.state == .idle else { return }
            await model.load(from: providers)
        }
    }

    private var captureForm: some View {
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
                Section(capture.kind == .image ? "Image" : "Link") {
                    if let previewData = capture.previewImageData,
                       let preview = PlatformImage(data: previewData) {
                        Image(platformImage: preview)
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
                    if capture.kind == .link {
                        Text(capture.urlString)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
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

private extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}
