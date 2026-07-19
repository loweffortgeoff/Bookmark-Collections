import SwiftData
import SwiftUI

struct AccentPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppAccent.storageKey) private var accentKey = AppAccent.defaultAccent.rawValue
    @Query(sort: [SortDescriptor(\Bookmark.createdAt), SortDescriptor(\Bookmark.id)])
    private var bookmarks: [Bookmark]

    private var selected: AppAccent {
        AppAccent(storedKey: accentKey)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 56), spacing: 14)],
                        spacing: 20
                    ) {
                        ForEach(AppAccent.allCases) { accent in
                            AccentSwatch(accent: accent, isSelected: accent == selected) {
                                accentKey = accent.rawValue
                            }
                        }
                    }
                    .padding(.vertical, 10)
                } header: {
                    Text("Theme Colors")
                } footer: {
                    Label(
                        "Every color is tuned for both light and dark, so your menus stay readable.",
                        systemImage: "info.circle"
                    )
                    .padding(.top, 4)
                }

                Section("Preview") {
                    HStack {
                        Label("All Items", systemImage: "square.grid.2x2")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(LibraryDestination.allItems.count(in: bookmarks))")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                            .monospacedDigit()
                    }
                    .listRowBackground(selectedRowBackground)
                    HStack {
                        Label("Favorites", systemImage: "star.fill")
                        Spacer()
                        Text("\(LibraryDestination.favorites.count(in: bookmarks))")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                            .monospacedDigit()
                    }
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Accent Color")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 540, minHeight: 520, idealHeight: 560)
        #endif
        .tint(selected.color)
    }

    private var selectedRowBackground: some View {
        ZStack(alignment: .leading) {
            selected.color.opacity(0.16)
            Capsule()
                .fill(selected.color)
                .frame(width: 3)
                .padding(.vertical, 9)
        }
    }
}

private struct AccentSwatch: View {
    let accent: AppAccent
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(accent.color)
                        .frame(width: 40, height: 40)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(colorScheme == .dark ? Color.black.opacity(0.72) : .white)
                    }
                }
                .frame(width: 48, height: 48)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(accent.color, lineWidth: 2.5)
                    }
                }
                .contentShape(Circle())
                Text(accent.displayName)
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accent.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    AccentPickerView()
        .modelContainer(for: Bookmark.self, inMemory: true)
}
