import SwiftData
import SwiftUI

/// All entries, grouped by day, newest first. Loads a window of days and can extend it.
struct EntriesView: View {
    private static let pageDays = 14

    @State private var days = pageDays
    @State private var editing: EditTarget?

    var body: some View {
        let since = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: .now))!
        EntriesList(since: since, onEdit: { editing = .existing($0) }, onShowMore: { days += Self.pageDays })
            // Re-create the list (and its query) when the window grows.
            .id(days)
            .navigationTitle("Entries")
            .toolbar {
                Button("New entry", systemImage: "plus") { editing = .new }
                    .help("Add a manual entry")
            }
            .sheet(item: $editing) { $0.editor }
    }
}

private struct EntriesList: View {
    let onEdit: (TimeEntry) -> Void
    let onShowMore: () -> Void

    @Environment(TrackingService.self) private var tracking
    @Environment(ErrorReporter.self) private var errors
    @AppStorage(AppSettings.Key.pomodoroEnabled) private var usePomodoro = false
    @Query private var entries: [TimeEntry]
    @State private var selection: TimeEntry.ID?
    @State private var pendingDelete: TimeEntry?

    init(since: Date, onEdit: @escaping (TimeEntry) -> Void, onShowMore: @escaping () -> Void) {
        self.onEdit = onEdit
        self.onShowMore = onShowMore
        _entries = Query(filter: #Predicate<TimeEntry> { $0.start >= since }, sort: \TimeEntry.start, order: .reverse)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let overlapping = EntryAnalysis.overlappingIDs(in: entries, now: now)

            List(selection: $selection) {
                if entries.isEmpty {
                    Text("No entries in this period.").foregroundStyle(.secondary)
                }
                ForEach(EntryAnalysis.days(of: entries, now: now, calendar: .current)) { day in
                    Section {
                        ForEach(day.entries) { entry in
                            EntryListRow(entry: entry, now: now, overlaps: overlapping.contains(entry.id))
                                .tag(entry.id)
                        }
                    } header: {
                        HStack {
                            Text(Self.title(for: day.start))
                            Spacer()
                            Text(DurationFormat.clock(day.total)).monospacedDigit()
                        }
                    }
                }
                Button("Show earlier days", action: onShowMore)
                    .buttonStyle(.link)
            }
            .contextMenu(forSelectionType: TimeEntry.ID.self) { ids in
                if let entry = entry(for: ids) {
                    Button("Edit…") { onEdit(entry) }
                    Button("Continue") {
                        errors.run("Continuing the entry") { try tracking.continueEntry(entry, usePomodoro: usePomodoro) }
                    }
                    Divider()
                    Button("Delete…", role: .destructive) { pendingDelete = entry }
                }
            } primaryAction: { ids in
                if let entry = entry(for: ids) { onEdit(entry) }
            }
            .onDeleteCommand {
                if let entry = entry(for: [selection].compactMap { $0 }) { pendingDelete = entry }
            }
        }
        .confirmsDeletion(of: $pendingDelete)
    }

    private func entry(for ids: some Collection<TimeEntry.ID>) -> TimeEntry? {
        guard let id = ids.first else { return nil }
        return entries.first { $0.id == id }
    }

    private static func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

private struct EntryListRow: View {
    let entry: TimeEntry
    let now: Date
    let overlaps: Bool

    var body: some View {
        HStack(spacing: 10) {
            ColorDot(hex: entry.project?.colorHex ?? HexColor.fallback)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.entryDescription.isEmpty ? "No description" : entry.entryDescription)
                    .foregroundStyle(entry.entryDescription.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let project = entry.project {
                        Text(project.name)
                    }
                    ForEach(entry.tags ?? []) { tag in
                        Text("#\(tag.name)").foregroundStyle(Color(hex: tag.colorHex))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            if overlaps {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Overlaps another entry")
            }
            if entry.isPomodoro {
                Text("🍅").help("Pomodoro")
            }
            Text(timeRange)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(DurationFormat.clock(entry.duration(at: now)))
                .monospacedDigit()
                .fontWeight(entry.isRunning ? .semibold : .regular)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private var timeRange: String {
        let start = entry.start.formatted(date: .omitted, time: .shortened)
        guard let end = entry.end else { return "\(start)–now" }
        return "\(start)–\(end.formatted(date: .omitted, time: .shortened))"
    }
}
