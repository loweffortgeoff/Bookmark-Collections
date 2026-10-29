import SwiftUI

/// The Collection row shared by the bookmark and snippet forms. At
/// accessibility text sizes the system Form row wraps the value under the
/// label with an indent, so the label and a plain menu stack flush-leading.
struct CollectionPicker: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let collections: [BookmarkCollection]
    @Binding var selection: UUID?

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                Text("Collection")
                Menu {
                    picker
                        .pickerStyle(.inline)
                        .labelsHidden()
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedName)
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                    }
                }
                .tint(.secondary)
                .accessibilityLabel("Collection")
                .accessibilityValue(selectedName)
            }
        } else {
            picker
        }
    }

    private var picker: some View {
        Picker("Collection", selection: $selection) {
            Text("None").tag(nil as UUID?)
            ForEach(collections) { collection in
                Text(collection.name).tag(collection.id as UUID?)
            }
        }
    }

    private var selectedName: String {
        collections.first { $0.id == selection }?.name ?? "None"
    }
}
