import SwiftData
import SwiftUI

/// Opt-in sweep over active links. Results live only in this sheet: nothing
/// is written to a bookmark unless the person moves it to Recently Deleted.
struct BrokenLinkCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    private enum Phase: Equatable {
        case running(checked: Int, total: Int)
        case empty
        case offline
        case completed(totalChecked: Int, uncertainCount: Int)
    }

    @State private var phase: Phase = .running(checked: 0, total: 0)
    @State private var findings: [BrokenLinkFinding] = []
    @State private var runID = UUID()
    @State private var confirmsMoveAll = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Check for Broken Links")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar { toolbar }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 380)
        #endif
        .task(id: runID) { await runSweep() }
        .confirmationDialog(
            "Move \(findings.count) broken links to Recently Deleted?",
            isPresented: $confirmsMoveAll,
            titleVisibility: .visible
        ) {
            Button("Move All to Recently Deleted", role: .destructive, action: moveAllToRecentlyDeleted)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They remain recoverable for 30 days.")
        }
        .alert("Couldn’t Move Link", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case let .running(checked, total):
            VStack(spacing: 16) {
                ProgressView(value: Double(checked), total: Double(max(total, 1)))
                Text("Checking \(checked) of \(total) links…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("brokenLinks.progress")
        case .empty:
            ContentUnavailableView(
                "No Links to Check",
                systemImage: "link",
                description: Text("Save some web links first. Images and snippets are not checked.")
            )
        case .offline:
            ContentUnavailableView {
                Label("Couldn’t Reach the Internet", systemImage: "wifi.slash")
            } description: {
                Text("Connect to the internet to check your links for broken addresses.")
            } actions: {
                Button("Retry") { runID = UUID() }
                    .buttonStyle(.borderedProminent)
            }
            .accessibilityIdentifier("brokenLinks.offline")
        case let .completed(totalChecked, uncertainCount):
            if findings.isEmpty {
                ContentUnavailableView(
                    "All checked links look reachable",
                    systemImage: "checkmark.circle",
                    description: Text(summary(totalChecked: totalChecked, uncertainCount: uncertainCount))
                )
                .accessibilityIdentifier("brokenLinks.allClear")
            } else {
                findingsList(totalChecked: totalChecked, uncertainCount: uncertainCount)
            }
        }
    }

    private func findingsList(totalChecked: Int, uncertainCount: Int) -> some View {
        List {
            Section {
                ForEach(findings) { finding in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(finding.title.isEmpty ? finding.domain : finding.title)
                            .font(.headline)
                        Text(finding.domain)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Label(finding.reason.localizedDescription, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        ViewThatFits(in: .horizontal) {
                            HStack { rowActions(for: finding) }
                            VStack(alignment: .leading) { rowActions(for: finding) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text(summary(totalChecked: totalChecked, uncertainCount: uncertainCount))
            }

            Section {
                Button("Move All to Recently Deleted", systemImage: "trash", role: .destructive) {
                    confirmsMoveAll = true
                }
                .accessibilityIdentifier("brokenLinks.moveAll")
            }
        }
        .accessibilityIdentifier("brokenLinks.findings")
    }

    @ViewBuilder
    private func rowActions(for finding: BrokenLinkFinding) -> some View {
        Button("Open in Browser", systemImage: "safari") { openURL(finding.url) }
        Button("Move to Recently Deleted", systemImage: "trash", role: .destructive) {
            moveToRecentlyDeleted(finding)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if case .running = phase {
            ToolbarItem(placement: .cancellationAction) {
                // Dismissing cancels the sweep's task.
                Button("Cancel") { dismiss() }
            }
        } else {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func summary(totalChecked: Int, uncertainCount: Int) -> String {
        if uncertainCount > 0 {
            return String(localized: "Checked \(totalChecked) links. \(uncertainCount) couldn’t be confirmed and were skipped.")
        }
        return String(localized: "Checked \(totalChecked) links.")
    }

    private func runSweep() async {
        findings = []
        let bookmarks = (try? modelContext.fetch(FetchDescriptor<Bookmark>())) ?? []
        let targets = BrokenLinkChecker.targets(from: bookmarks)
        guard !targets.isEmpty else {
            phase = .empty
            return
        }
        phase = .running(checked: 0, total: targets.count)
        let result = await BrokenLinkChecker().check(targets) { progress in
            await MainActor.run {
                if case .running = phase {
                    phase = .running(checked: progress.checked, total: progress.total)
                }
            }
        }
        guard !result.wasCancelled, !Task.isCancelled else { return }
        if result.abortedOffline {
            phase = .offline
        } else {
            findings = result.findings
            phase = .completed(totalChecked: result.totalChecked, uncertainCount: result.uncertainCount)
        }
    }

    private func bookmark(for finding: BrokenLinkFinding) -> Bookmark? {
        modelContext.model(for: finding.id) as? Bookmark
    }

    private func moveToRecentlyDeleted(_ finding: BrokenLinkFinding) {
        do {
            if let bookmark = bookmark(for: finding), bookmark.deletedAt == nil {
                try BookmarkRepository(context: modelContext).softDelete(bookmark)
            }
            findings.removeAll { $0.id == finding.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveAllToRecentlyDeleted() {
        for finding in findings {
            moveToRecentlyDeleted(finding)
        }
    }
}
