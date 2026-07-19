import SwiftUI

struct AccentPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppAccent.storageKey) private var accentKey = AppAccent.defaultAccent.rawValue

    private var selected: AppAccent {
        AppAccent(storedKey: accentKey)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 10)], spacing: 18) {
                        ForEach(AppAccent.allCases) { accent in
                            AccentSwatch(accent: accent, isSelected: accent == selected) {
                                accentKey = accent.rawValue
                            }
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Theme Colors")
                } footer: {
                    Label(
                        "Every color is tuned for both light and dark, so your menus stay readable.",
                        systemImage: "info.circle"
                    )
                }

                Section("Preview") {
                    HStack {
                        Label("All Items", systemImage: "square.grid.2x2")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("128")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                    }
                    .listRowBackground(selectedRowBackground)
                    HStack {
                        Label("Favorites", systemImage: "star.fill")
                        Spacer()
                        Text("12")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                    }
                }
            }
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
        .frame(minWidth: 400, minHeight: 480)
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
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(accent.color)
                        .frame(width: 38, height: 38)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(colorScheme == .dark ? Color.black.opacity(0.72) : .white)
                    }
                }
                .frame(width: 44, height: 44)
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
}
