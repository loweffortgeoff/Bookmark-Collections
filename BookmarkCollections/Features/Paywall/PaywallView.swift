import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Storefront.self) private var storefront

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "bookmark.fill")
                    .font(.system(.largeTitle, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Save More Than 10 Bookmarks")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("Unlock Tucked Pro to keep saving links, images, and snippets.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Text(storefront.product?.displayPrice ?? "$7.99")
                        .font(.title3.weight(.semibold))
                    Text("Lifetime unlock")
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = storefront.errorMessage {
                    Text(errorMessage)
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
                        Text("Unlock Tucked Pro")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(storefront.product == nil || storefront.isLoading)

                Button("Restore Purchases") {
                    Task { await storefront.restorePurchases() }
                }
                .disabled(storefront.isLoading)
            }
            .padding(28)
            .frame(maxWidth: 420)
            .navigationTitle("Tucked Pro")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("paywall")
    }
}
