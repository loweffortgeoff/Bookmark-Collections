import StoreKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Storefront.self) private var storefront
    @Environment(SyncHealthMonitor.self) private var syncHealth
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onPaywall: () -> Void

    @State private var isImporting = false
    @State private var importSummary: ImportSummary?
    @State private var exportDocument: ExportFileDocument?
    @State private var exportType: UTType = .json
    @State private var exportFilename = "Tucked Bookmarks"
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var showsBrokenLinkCheck = false

    var body: some View {
        NavigationStack {
            Form {
                if storefront.isUnlocked {
                    Section { ProBadgeRow() }
                } else if PaywallConfiguration.isEnabled {
                    Section("Tucked for Life") {
                        Button("Unlock Tucked for Life", systemImage: "lock.open", action: onPaywall)
                            .accessibilityIdentifier("settings.unlock")
                        Button("Restore Purchases", systemImage: "arrow.clockwise") {
                            Task { await storefront.restorePurchases() }
                        }
                        .accessibilityIdentifier("settings.restorePurchases")
                        if let message = storefront.errorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button("Import Links", systemImage: "square.and.arrow.down", action: beginImport)
                        .accessibilityIdentifier("settings.importLinks")
                    Button("Export HTML", systemImage: "safari", action: exportHTML)
                        .accessibilityIdentifier("settings.exportHTML")
                    Button("Export JSON", systemImage: "archivebox", action: exportJSON)
                        .accessibilityIdentifier("settings.exportJSON")
                    Button("Check for Broken Links", systemImage: "checklist") {
                        showsBrokenLinkCheck = true
                    }
                    .accessibilityIdentifier("settings.checkBrokenLinks")
                } header: {
                    Text("Library Data")
                } footer: {
                    Text("HTML exports links for other browsers. JSON backs up links and snippets. Image bookmarks are not exported.")
                }

                Section("iCloud") {
                    Label(syncHealth.status.title, systemImage: syncHealth.status.systemImage)
                        .accessibilityIdentifier("settings.syncStatus")
                    LabeledContent("Last iCloud push", value: SyncHealthMonitor.formattedTimestamp(syncHealth.lastPushDate))
                        .accessibilityIdentifier("settings.syncLastPush")
                    LabeledContent("Last iCloud pull", value: SyncHealthMonitor.formattedTimestamp(syncHealth.lastPullDate))
                        .accessibilityIdentifier("settings.syncLastPull")
                    Text("Shows iCloud account availability and the last sync activity observed by Tucked on this device. Bookmark changes are saved locally first and mirrored by iCloud when available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                WeAlsoMakeSection()

                Section("About") {
                    versionRow
                    Button {
                        requestReview()
                    } label: {
                        Label {
                            Text("Rate & Review")
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                    .accessibilityIdentifier("settings.rateReview")
                    ForEach(AboutLink.allCases) { link in
                        Link(destination: link.url) {
                            Label(link.title, systemImage: link.systemImage)
                        }
                        .accessibilityIdentifier(link.accessibilityIdentifier)
                    }
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 520, minHeight: 480, idealHeight: 500)
        #endif
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            syncHealth.start()
            await syncHealth.refresh()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText, .json],
            allowsMultipleSelection: false,
            onCompletion: importFiles
        )
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportType,
            defaultFilename: exportFilename,
            onCompletion: handleExportCompletion
        )
        .sheet(isPresented: $showsBrokenLinkCheck) {
            BrokenLinkCheckView()
        }
        .sheet(isPresented: importSummaryPresented) {
            if let importSummary {
                ImportSummaryView(summary: importSummary)
            }
        }
        .alert("Couldn’t Complete Data Operation", isPresented: errorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    private var versionRow: some View {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
        return layout {
            Text("Version")
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Text(verbatim: "\(version) (\(build))")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.version")
    }

    private func beginImport() {
        isImporting = true
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            let url = try result.get().first
            guard let url else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            if url.pathExtension.localizedCaseInsensitiveCompare("json") == .orderedSame {
                importSummary = try LibraryImportService(context: modelContext).importJSON(data)
            } else {
                guard let text = String(data: data, encoding: .utf8) else {
                    throw SettingsDataError.invalidTextEncoding
                }
                importSummary = try LibraryImportService(context: modelContext).importText(text)
            }
        } catch {
            if error as? BookmarkRepository.LimitError == .limitReached {
                onPaywall()
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func exportHTML() {
        prepareExport(type: .html, filename: "Tucked Bookmarks.html") {
            try LibraryExportService(context: modelContext).exportHTML()
        }
    }

    private func exportJSON() {
        prepareExport(type: .json, filename: "Tucked Backup.json") {
            try LibraryExportService(context: modelContext).exportJSON()
        }
    }

    private func prepareExport(type: UTType, filename: String, data: () throws -> Data) {
        do {
            exportDocument = ExportFileDocument(data: try data(), contentType: type)
            exportType = type
            exportFilename = filename
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleExportCompletion(_ result: Result<URL, Error>) {
        if case let .failure(error) = result {
            errorMessage = error.localizedDescription
        }
        exportDocument = nil
    }

    private var importSummaryPresented: Binding<Bool> {
        Binding(
            get: { importSummary != nil },
            set: { if !$0 { importSummary = nil } }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

enum AboutLink: String, CaseIterable, Identifiable {
    case privacyPolicy = "https://www.loweffortapps.app/privacy/"
    case support = "https://www.loweffortapps.app/support/"
    case website = "https://www.loweffortapps.app/"

    var id: String { rawValue }

    var url: URL {
        guard let url = URL(string: rawValue) else {
            preconditionFailure("About link is not a URL: \(rawValue)")
        }
        return url
    }

    var title: String {
        switch self {
        case .privacyPolicy: "Privacy Policy"
        case .support: "Support"
        case .website: "Low Effort Apps"
        }
    }

    var systemImage: String {
        switch self {
        case .privacyPolicy: "hand.raised"
        case .support: "questionmark.circle"
        case .website: "globe"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .privacyPolicy: "settings.privacyPolicy"
        case .support: "settings.support"
        case .website: "settings.website"
        }
    }
}

private struct ExportFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    static var writableContentTypes: [UTType] { [.html, .json] }

    let data: Data
    let contentType: UTType

    init(data: Data, contentType: UTType) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum SettingsDataError: LocalizedError {
    case invalidTextEncoding

    var errorDescription: String? {
        "The selected text file is not valid UTF-8."
    }
}
