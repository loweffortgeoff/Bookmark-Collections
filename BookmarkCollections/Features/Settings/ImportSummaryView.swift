import SwiftUI

struct ImportSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let summary: ImportSummary

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("New Bookmarks", value: summary.newCount.formatted())
                LabeledContent("Duplicates Updated", value: summary.duplicateCount.formatted())
                LabeledContent("Restored", value: summary.restoredCount.formatted())
                LabeledContent("Invalid Lines", value: summary.failedLines.count.formatted())

                if !summary.failedLines.isEmpty {
                    Section("Couldn’t Import") {
                        ForEach(Array(summary.failedLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("Import Complete")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
    }
}
