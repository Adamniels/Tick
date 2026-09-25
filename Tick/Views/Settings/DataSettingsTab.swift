import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Export (D35). Import (Toggl CSV, restoring a Tick export) belongs here too, in M8.
struct DataSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportFile: ExportFile?
    @State private var exportType = UTType.json
    @State private var exportName = ""
    @State private var exportSummary = ""
    @State private var exportMessage: String?

    var body: some View {
        Form {
            Section {
                Button("Export all data (JSON)…") { prepareExport(csv: false) }
                Button("Export time entries (CSV)…") { prepareExport(csv: true) }
                if let exportMessage {
                    Text(exportMessage).foregroundStyle(.secondary)
                }
            } header: {
                Text("Export")
            } footer: {
                Text("JSON contains everything, times exact to the millisecond: projects, tags, entries, pomodoro sessions and these settings. "
                    + "Use it to move to a new app or database. CSV has one row per time entry, for spreadsheets or "
                    + "another time tracker.")
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
            document: exportFile,
            contentType: exportType,
            defaultFilename: exportName
        ) { result in
            switch result {
            case .success(let url): exportMessage = "Exported \(exportSummary) to \(url.lastPathComponent)."
            case .failure(let error): exportMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func prepareExport(csv: Bool) {
        do {
            let archive = try DataExport.archive(context: modelContext, settings: DataExport.currentSettings, now: .now)
            let day = Date.now.formatted(.iso8601.year().month().day())
            exportSummary = "\(archive.entries.count) entries"
                + (csv ? "" : ", \(archive.projects.count) projects, \(archive.tags.count) tags")
            exportName = csv ? "Tick entries \(day)" : "Tick export \(day)"
            exportType = csv ? .commaSeparatedText : .json
            exportFile = ExportFile(data: csv ? Data(DataExport.csv(archive).utf8) : try DataExport.json(archive))
            exportMessage = nil
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

/// Bytes handed to the system save panel (`fileExporter`).
nonisolated struct ExportFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .commaSeparatedText]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
