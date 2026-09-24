import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Everything Tick stores, in a stable, documented shape (D35). Complete: ids are kept and
/// relationships are id references, so the data can be rebuilt in another app or database.
/// Times are ISO 8601 in UTC, exact to the millisecond.
/// `formatVersion` changes whenever the shape changes, so a future importer knows what it reads.
nonisolated struct ExportArchive: Codable, Equatable {
    static let currentFormatVersion = 1

    var formatVersion = ExportArchive.currentFormatVersion
    var app = "Tick"
    var exportedAt: Date
    var projects: [ProjectRecord]
    var tags: [TagRecord]
    var entries: [EntryRecord]
    var pomodoroSessions: [PomodoroRecord]
    /// This Mac's local settings (not synced).
    var settings: SettingsRecord

    struct ProjectRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var colorHex: String
        var isArchived: Bool
        var createdAt: Date
    }

    struct TagRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var colorHex: String
        var isArchived: Bool
    }

    struct EntryRecord: Codable, Equatable {
        var id: UUID
        var description: String
        var start: Date
        /// `nil` for the running entry.
        var end: Date?
        var isPomodoro: Bool
        var projectID: UUID?
        var tagIDs: [UUID]
        var updatedAt: Date
    }

    struct PomodoroRecord: Codable, Equatable {
        var id: UUID
        var runID: UUID
        var phase: String
        var start: Date
        var plannedEnd: Date
        var endedAt: Date?
        var completed: Bool
    }

    struct SettingsRecord: Codable, Equatable {
        var pomodoroEnabled: Bool
        var pomodoro: PomodoroSettings
        var reminders: ReminderSettings
        var popup: OverlayAppearance
    }
}

enum DataExport {
    static func archive(context: ModelContext, settings: ExportArchive.SettingsRecord, now: Date) throws -> ExportArchive {
        let projects = try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt)]))
        let tags = try context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)]))
        let entries = try context.fetch(FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.start)]))
        let sessions = try context.fetch(FetchDescriptor<PomodoroSession>(sortBy: [SortDescriptor(\.start)]))

        return ExportArchive(
            exportedAt: now,
            projects: projects.map {
                .init(id: $0.id, name: $0.name, colorHex: $0.colorHex, isArchived: $0.isArchived, createdAt: $0.createdAt)
            },
            tags: tags.map { .init(id: $0.id, name: $0.name, colorHex: $0.colorHex, isArchived: $0.isArchived) },
            entries: entries.map {
                .init(
                    id: $0.id, description: $0.entryDescription, start: $0.start, end: $0.end,
                    isPomodoro: $0.isPomodoro, projectID: $0.project?.id,
                    tagIDs: ($0.tags ?? []).map(\.id).sorted { $0.uuidString < $1.uuidString },
                    updatedAt: $0.updatedAt
                )
            },
            pomodoroSessions: sessions.map {
                .init(
                    id: $0.id, runID: $0.runID, phase: $0.phase, start: $0.start, plannedEnd: $0.plannedEnd,
                    endedAt: $0.endedAt, completed: $0.completed
                )
            },
            settings: settings
        )
    }

    static var currentSettings: ExportArchive.SettingsRecord {
        .init(
            pomodoroEnabled: UserDefaults.standard.bool(forKey: AppSettings.Key.pomodoroEnabled),
            pomodoro: AppSettings.pomodoro,
            reminders: AppSettings.reminders,
            popup: AppSettings.overlayAppearance
        )
    }

    /// Pretty-printed JSON with ISO 8601 times in UTC, exact to the millisecond (the portable
    /// standard; sub-millisecond clock noise isn't kept).
    nonisolated static func json(_ archive: ExportArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: true)))
        }
        return try encoder.encode(archive)
    }

    nonisolated static func decode(_ data: Data) throws -> ExportArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            return try Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
        }
        return try decoder.decode(ExportArchive.self, from: data)
    }

    /// Time entries as CSV, with Toggl-like columns plus exact ISO 8601 times. Local dates and
    /// times use `timeZone`; the ISO columns are unambiguous.
    nonisolated static func csv(_ archive: ExportArchive, timeZone: TimeZone = .current) -> String {
        let projects = Dictionary(uniqueKeysWithValues: archive.projects.map { ($0.id, $0.name) })
        let tags = Dictionary(uniqueKeysWithValues: archive.tags.map { ($0.id, $0.name) })
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        func date(_ value: Date?) -> String {
            guard let value else { return "" }
            let c = calendar.dateComponents([.year, .month, .day], from: value)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        func time(_ value: Date?) -> String {
            guard let value else { return "" }
            let c = calendar.dateComponents([.hour, .minute, .second], from: value)
            return String(format: "%02d:%02d:%02d", c.hour!, c.minute!, c.second!)
        }
        func iso(_ value: Date?) -> String {
            value?.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)) ?? ""
        }

        let header = [
            "Description", "Project", "Tags", "Start date", "Start time", "End date", "End time",
            "Duration", "Duration (hours)", "Pomodoro", "Start (ISO 8601)", "End (ISO 8601)", "ID",
        ]
        let rows = archive.entries.map { entry -> [String] in
            let duration = entry.end.map { $0.timeIntervalSince(entry.start) }
            return [
                entry.description,
                entry.projectID.flatMap { projects[$0] } ?? "",
                entry.tagIDs.compactMap { tags[$0] }.sorted().joined(separator: ", "),
                date(entry.start), time(entry.start), date(entry.end), time(entry.end),
                duration.map(DurationFormat.clock) ?? "",
                duration.map { String(format: "%.4f", $0 / 3600) } ?? "",
                entry.isPomodoro ? "yes" : "no",
                iso(entry.start), iso(entry.end), entry.id.uuidString,
            ]
        }
        return ([header] + rows).map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// RFC 4180: quote fields containing commas, quotes or line breaks; double inner quotes.
    nonisolated static func csvField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
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
