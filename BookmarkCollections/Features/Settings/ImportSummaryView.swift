import SwiftUI

struct ImportSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let summary: ImportSummary
    var title: LocalizedStringKey = "Import Complete"
    var stoppedFooter: LocalizedStringKey = "The rest of the file was not imported."
    @State private var showsPaywall = false

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("New Bookmarks", value: summary.newCount.formatted())
                LabeledContent("Duplicates Updated", value: summary.duplicateCount.formatted())
                LabeledContent("Restored", value: summary.restoredCount.formatted())
                LabeledContent("Invalid Lines", value: summary.failedLines.count.formatted())

                if summary.stoppedAtLimit {
                    Section {
                        Button("Unlock Tucked for Life", systemImage: "lock.open") {
                            showsPaywall = true
                        }
                        .accessibilityIdentifier("importSummary.unlock")
                    } header: {
                        Text("Stopped at the free limit")
                    } footer: {
                        Text(stoppedFooter)
                    }
                }

                if !summary.failedLines.isEmpty {
                    Section("Couldn’t Import") {
                        ForEach(Array(summary.failedLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
        .sheet(isPresented: $showsPaywall) { PaywallView() }
    }
}
