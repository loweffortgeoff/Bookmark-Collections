import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Storefront.self) private var storefront

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    PaywallHeader()

                    VStack(alignment: .leading, spacing: 16) {
                        PaywallFeatureRow(
                            symbol: "infinity",
                            title: "Unlimited bookmarks",
                            detail: "Links, images, and snippets. As many as you like."
                        )
                        PaywallFeatureRow(
                            symbol: "square.and.arrow.down",
                            title: "Save from any app",
                            detail: "The share sheet keeps working past ten."
                        )
                        PaywallFeatureRow(
                            symbol: "icloud",
                            title: "Everywhere you are",
                            detail: "Your collections sync across your devices."
                        )
                        PaywallFeatureRow(
                            symbol: "heart",
                            title: "One payment, no subscription",
                            detail: "Pay once. It stays unlocked."
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    PaywallPurchaseSection()
                }
                .padding(28)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Tucked for Life")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 520, minHeight: 560, idealHeight: 620)
        #endif
        .accessibilityIdentifier("paywall")
    }
}

private struct PaywallHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.fill")
                .font(.system(.largeTitle, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(24)
                .background(.tint.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Ten Bookmarks Is Not Enough")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("You have things to tuck away. Keep tucking.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct PaywallFeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PaywallPurchaseSection: View {
    @Environment(Storefront.self) private var storefront

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(storefront.product?.displayPrice ?? "$7.99")
                    .font(.title3.weight(.semibold))
                Text("One time. Yours forever.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = storefront.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await storefront.purchase() }
            } label: {
                if storefront.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Unlock Tucked for Life")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(storefront.product == nil || storefront.isLoading)

            Button("Restore Purchases") {
                Task { await storefront.restorePurchases() }
            }
            .disabled(storefront.isLoading)
        }
    }
}
