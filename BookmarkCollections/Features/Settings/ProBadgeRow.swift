import SwiftUI

struct ProBadgeRow: View {
    var body: some View {
        Label("Tucked for Life", systemImage: "checkmark.seal.fill")
            .foregroundStyle(.tint)
            .accessibilityLabel("Tucked for Life unlocked")
            .accessibilityIdentifier("settings.proBadge")
    }
}
