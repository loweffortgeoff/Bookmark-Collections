import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Storefront.self) private var storefront
    let onPaywall: () -> Void

    @StateObject private var syncHealth = SyncHealthMonitor()
    @State private var isImporting = false
    @State private var importSummary: ImportSummary?
    @State private var exportDocument: ExportFileDocument?
    @State private var exportType: UTType = .json
    @State private var exportFilename = "Bookmark Collections"
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if storefront.isUnlocked {
                    Section { ProBadgeRow() }
                }

                Section("Library Data") {
                    Button("Import Links", systemImage: "square.and.arrow.down", action: beginImport)
                        .accessibilityIdentifier("settings.importLinks")
                    Button("Export HTML", systemImage: "safari", action: exportHTML)
                        .accessibilityIdentifier("settings.exportHTML")
                    Button("Export JSON", systemImage: "archivebox", action: exportJSON)
                        .accessibilityIdentifier("settings.exportJSON")
                }

                Section("iCloud") {
                    Label(syncHealth.status.title, systemImage: syncHealth.status.systemImage)
                        .accessibilityIdentifier("settings.syncStatus")
                    Text("This reports account availability only. Bookmark changes are saved locally first and mirrored by iCloud when available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        prepareExport(type: .html, filename: "Bookmark Collections.html") {
            try LibraryExportService(context: modelContext).exportHTML()
        }
    }

    private func exportJSON() {
        prepareExport(type: .json, filename: "Bookmark Collections.json") {
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
