import SwiftUI

/// Another live Low Effort Apps product, shown in Settings.
struct LowEffortApp: Identifiable, Equatable, Sendable {
    let name: String
    /// Asset catalog image with light and dark variants.
    let iconName: String
    let appStoreID: String
    /// App Store URL slug when it differs from the lowercased, hyphenated name.
    let slug: String?

    var id: String { appStoreID }

    var appStoreURL: URL? {
        let urlSlug = slug ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
        return URL(string: "https://apps.apple.com/us/app/\(urlSlug)/id\(appStoreID)")
    }
}

enum LowEffortApps {
    /// Tucked's App Store review page. A link always opens it, unlike
    /// requestReview(), which the system may silently skip.
    /// On macOS the https form opens the product page without the review
    /// sheet; the macappstore scheme opens Write a Review (Mac mini, macOS 27.2).
    #if os(macOS)
    static let tuckedWriteReviewURL = URL(string: "macappstore://apps.apple.com/app/id6792490401?action=write-review")!
    #else
    static let tuckedWriteReviewURL = URL(string: "https://apps.apple.com/app/id6792490401?action=write-review")!
    #endif

    /// The other live apps, never Tucked itself. IDs checked against the
    /// App Store lookup on 2026-11-26.
    static let otherApps: [LowEffortApp] = [
        LowEffortApp(name: "Task(ed)", iconName: "tasked", appStoreID: "6755186421", slug: "task-ed"),
        LowEffortApp(name: "EveryPaw", iconName: "everypaw", appStoreID: "6754781167", slug: nil),
        LowEffortApp(name: "AisleWise", iconName: "aislewise", appStoreID: "6755057084", slug: nil),
        LowEffortApp(name: "Weather in Words", iconName: "weatherinwords", appStoreID: "6806063498", slug: nil),
        LowEffortApp(name: "Offshoots", iconName: "offshoots", appStoreID: "6757363128", slug: nil)
    ]
}

struct WeAlsoMakeSection: View {
    var body: some View {
        Section("We Also Make") {
            ForEach(LowEffortApps.otherApps) { app in
                OtherAppRow(app: app)
            }
        }
    }
}

private struct OtherAppRow: View {
    let app: LowEffortApp
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let url = app.appStoreURL {
            Link(destination: url) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    Image(app.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityHidden(true)
                    Text(app.name)
                        .foregroundStyle(.primary)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(app.name)
            .accessibilityHint("Opens the App Store")
            .accessibilityIdentifier("settings.otherApp.\(app.appStoreID)")
        }
    }
}
