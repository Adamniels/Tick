import SwiftData
import SwiftUI

/// A Toggl-like day view (M7): entries as blocks on a 24-hour timeline, edited by clicking and dragging.
struct CalendarView: View {
    @State private var day = Calendar.current.startOfDay(for: .now)
    @AppStorage("calendar.hourHeight") private var hourHeight = 60.0

    var body: some View {
        CalendarDayView(
            day: day,
            hourHeight: hourHeight,
            onChangeDay: { offset in
                day = Calendar.current.date(byAdding: .day, value: offset, to: day) ?? day
            },
            onToday: { day = Calendar.current.startOfDay(for: .now) },
            onZoom: { step in hourHeight = min(160, max(30, hourHeight + step)) }
        )
        // A new day needs a new query and scroll position.
        .id(day)
        .navigationTitle("Calendar")
    }
}

/// One day: header, the entries' query, and what happens when the timeline asks to edit,
/// create, change, continue or delete an entry.
private struct CalendarDayView: View {
    let day: Date
    let hourHeight: CGFloat
    let onChangeDay: (Int) -> Void
    let onToday: () -> Void
    let onZoom: (Double) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingService.self) private var tracking
    @Environment(ErrorReporter.self) private var errors
    @AppStorage(AppSettings.Key.pomodoroEnabled) private var usePomodoro = false
    @Query private var entries: [TimeEntry]
    @State private var editing: EditTarget?
    @State private var pendingDelete: TimeEntry?

    init(day: Date, hourHeight: CGFloat, onChangeDay: @escaping (Int) -> Void, onToday: @escaping () -> Void,
         onZoom: @escaping (Double) -> Void) {
        self.day = day
        self.hourHeight = hourHeight
        self.onChangeDay = onChangeDay
        self.onToday = onToday
        self.onZoom = onZoom
        let from = day - TimeEntry.queryLookback
        let to = CalendarLayout.interval(ofDay: day, calendar: .current).end
        _entries = Query(filter: #Predicate<TimeEntry> { $0.start >= from && $0.start < to }, sort: \TimeEntry.start)
    }

    var body: some View {
        let interval = CalendarLayout.interval(ofDay: day, calendar: .current)

        TimelineView(.periodic(from: .now, by: 15)) { context in
            let now = context.date
            let visible = entries.filter { ($0.end ?? now) > interval.start }
            VStack(spacing: 0) {
                header(total: visible.reduce(0) { $0 + (Statistics.clip($1, to: interval, now: now)?.duration ?? 0) })
                Divider()
                CalendarTimeline(
                    day: day,
                    hourHeight: hourHeight,
                    entries: visible,
                    now: now,
                    onEdit: { editing = .existing($0) },
                    onCreate: { start, end in editing = .draft(EntryDraft(start: start, end: end)) },
                    onChange: change,
                    onContinue: { entry in
                        errors.run("Continuing the entry") { try tracking.continueEntry(entry, usePomodoro: usePomodoro) }
                    },
                    onDelete: { pendingDelete = $0 }
                )
            }
        }
        .sheet(item: $editing) { $0.editor }
        .confirmsDeletion(of: $pendingDelete)
    }

    private func header(total: TimeInterval) -> some View {
        HStack(spacing: 10) {
            Button("Previous day", systemImage: "chevron.left") { onChangeDay(-1) }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Next day", systemImage: "chevron.right") { onChangeDay(1) }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            Text(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.title3.weight(.semibold))
            if Calendar.current.isDateInToday(day) {
                Text("TODAY")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: .capsule)
            } else {
                Button("Today", action: onToday)
            }
            Spacer()
            Text(DurationFormat.clock(total))
                .font(.title3.monospacedDigit())
            Button("Zoom out", systemImage: "minus.magnifyingglass") { onZoom(-15) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Zoom in", systemImage: "plus.magnifyingglass") { onZoom(15) }
                .keyboardShortcut("+", modifiers: .command)
            Button("New entry", systemImage: "plus") { editing = .new }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Applies a finished drag. The running entry keeps running: only its start can change.
    private func change(_ entry: TimeEntry, start: Date, end: Date) {
        var draft = EntryDraft(entry: entry)
        draft.start = start
        if !entry.isRunning { draft.end = end }
        guard draft.validationError(now: .now) == nil else { return }
        errors.run("Changing the entry") { try TimerService(context: modelContext).save(draft, to: entry) }
    }
}
