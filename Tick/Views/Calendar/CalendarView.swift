import OSLog
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

private struct CalendarDayView: View {
    let day: Date
    let hourHeight: CGFloat
    let onChangeDay: (Int) -> Void
    let onToday: () -> Void
    let onZoom: (Double) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(PomodoroService.self) private var pomodoro
    @AppStorage(AppSettings.Key.pomodoroEnabled) private var usePomodoro = false
    @Query private var entries: [TimeEntry]
    @State private var editing: EditTarget?
    @State private var pendingDelete: TimeEntry?
    /// Where a block (or a new entry, `id == nil`) is being dragged to.
    @State private var preview: Preview?
    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// Latest scroll geometry, kept outside SwiftUI state so scrolling doesn't redraw the view.
    @State private var scroll = ScrollTracker()

    final class ScrollTracker {
        var offset: CGFloat = 0
        var viewportHeight: CGFloat = 0
    }

    struct Preview: Equatable {
        let id: UUID?
        let start: Date
        let end: Date
    }

    private static let space = "timeline"
    private static let gutter: CGFloat = 52
    private static let inset: CGFloat = 10

    init(day: Date, hourHeight: CGFloat, onChangeDay: @escaping (Int) -> Void, onToday: @escaping () -> Void,
         onZoom: @escaping (Double) -> Void) {
        self.day = day
        self.hourHeight = hourHeight
        self.onChangeDay = onChangeDay
        self.onToday = onToday
        self.onZoom = onZoom
        let from = day - StatsPeriod.fetchLookback
        let to = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        _entries = Query(filter: #Predicate<TimeEntry> { $0.start >= from && $0.start < to }, sort: \TimeEntry.start)
    }

    private var interval: DateInterval {
        DateInterval(start: day, end: Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day + 86_400)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let now = context.date
            let visible = entries.filter { ($0.end ?? now) > interval.start }
            VStack(spacing: 0) {
                header(total: visible.reduce(0) { $0 + (Statistics.clip($1, to: interval, now: now)?.duration ?? 0) })
                Divider()
                timeline(entries: visible, now: now)
            }
        }
        .sheet(item: $editing) { $0.editor }
        // Zoom around the middle of the view: the time there stays there.
        .onChange(of: hourHeight) { oldHeight, newHeight in
            let offset = CalendarLayout.zoomedOffset(
                currentOffset: scroll.offset, viewportHeight: scroll.viewportHeight, inset: Self.inset,
                oldHourHeight: oldHeight, newHourHeight: newHeight
            )
            // After layout, so the taller or shorter content can be scrolled to.
            DispatchQueue.main.async { scrollPosition.scrollTo(y: offset) }
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { entry in
            Button("Delete", role: .destructive) { perform { try TimerService(context: modelContext).delete(entry) } }
        } message: { entry in
            Text("\(ReminderService.label(for: entry)), \(DurationFormat.clock(entry.duration())). This can't be undone.")
        }
    }

    // MARK: - Header

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

    // MARK: - Timeline

    private func timeline(entries: [TimeEntry], now: Date) -> some View {
        let byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let blocks = CalendarLayout.blocks(
            for: entries.map { .init(id: $0.id, start: $0.start, end: $0.end ?? now) }, in: interval
        )

        return ScrollViewReader { proxy in
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    hourLabels
                    GeometryReader { geometry in
                        let width = geometry.size.width - 8
                        ZStack(alignment: .topLeading) {
                            background(now: now)
                            ForEach(blocks) { block in
                                if let entry = byID[block.id] {
                                    blockView(entry: entry, block: block, width: width, now: now)
                                }
                            }
                            if let preview, preview.id == nil {
                                newEntryPreview(preview, width: width)
                            }
                            if Calendar.current.isDateInToday(day) {
                                nowLine(now, width: width)
                            }
                        }
                        .coordinateSpace(.named(Self.space))
                    }
                    .frame(height: 24 * hourHeight)
                }
                .padding(.vertical, Self.inset)
            }
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: CGSize.self) { geometry in
                CGSize(width: geometry.contentOffset.y, height: geometry.containerSize.height)
            } action: { _, value in
                scroll.offset = value.width
                scroll.viewportHeight = value.height
            }
            .onAppear {
                let hour = initialHour(entries: entries, now: now)
                DispatchQueue.main.async { proxy.scrollTo(hour, anchor: .top) }
            }
        }
    }

    private var hourLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .offset(y: -7)
                    .frame(width: Self.gutter, height: hourHeight, alignment: .top)
                    .id(hour)
            }
        }
    }

    /// Grid lines, plus the empty-space gestures: click for a 30-minute entry, drag to create.
    private func background(now: Date) -> some View {
        Canvas { context, size in
            for hour in 0...24 {
                let y = CGFloat(hour) * hourHeight
                context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) },
                               with: .color(.secondary.opacity(0.2)), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .named(Self.space)) { location in
            let start = CalendarLayout.snapped(date(atY: location.y), from: day)
            editing = .draft(EntryDraft(start: start, end: min(start + 1800, interval.end)))
        }
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
                .onChanged { value in
                    let range = CalendarLayout.result(
                        of: .create(anchor: date(atY: value.startLocation.y)), delta: 0,
                        pointer: date(atY: value.location.y), day: interval
                    )
                    preview = Preview(id: nil, start: range.start, end: range.end)
                }
                .onEnded { _ in
                    if let preview { editing = .draft(EntryDraft(start: preview.start, end: preview.end)) }
                    preview = nil
                }
        )
    }

    private func blockView(entry: TimeEntry, block: CalendarLayout.Block, width: CGFloat, now: Date) -> some View {
        let shown = preview?.id == entry.id ? preview : nil
        let start = shown?.start ?? block.start
        let end = shown?.end ?? block.end
        let columnWidth = width / CGFloat(block.columnCount)
        let y = CalendarLayout.offset(of: start, from: day, hourHeight: hourHeight)
        // 1 pt gap so back-to-back entries stay visually separate.
        let height = max(CalendarLayout.blockHeight(from: start, to: end, hourHeight: hourHeight) - 1, 2)
        let canMove = !entry.isRunning && !block.continuesBefore && !block.continuesAfter
        let canResizeStart = !block.continuesBefore
        let canResizeEnd = !entry.isRunning && !block.continuesAfter

        return CalendarBlock(entry: entry, start: start, end: end, now: now, height: height, isDragging: shown != nil)
            .frame(width: max(columnWidth - 3, 10), height: height)
            .help(Self.tooltip(for: entry, start: start, end: end))
            .overlay(alignment: .top) {
                if canResizeStart {
                    resizeHandle(entry: entry, drag: .resizeStart(start: block.start, end: block.end), edge: .top)
                }
            }
            .overlay(alignment: .bottom) {
                if canResizeEnd {
                    resizeHandle(entry: entry, drag: .resizeEnd(start: block.start, end: block.end), edge: .bottom)
                }
            }
            .onTapGesture { editing = .existing(entry) }
            .gesture(
                dragGesture(entry: entry, drag: .move(start: block.start, end: block.end)),
                including: canMove ? .all : .subviews
            )
            .contextMenu {
                Button("Edit…") { editing = .existing(entry) }
                Button("Continue") { perform { try pomodoro.continueEntry(entry, usePomodoro: usePomodoro) } }
                Divider()
                Button("Delete…", role: .destructive) { pendingDelete = entry }
            }
            .offset(x: columnWidth * CGFloat(block.column) + 4, y: y)
    }

    private static func tooltip(for entry: TimeEntry, start: Date, end: Date) -> String {
        let range = "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
        return "\(ReminderService.label(for: entry))\n\(range)"
    }

    private func resizeHandle(entry: TimeEntry, drag: CalendarLayout.Drag, edge: VerticalEdge) -> some View {
        // Thin enough that a small block still has room in the middle to move it.
        Color.clear
            .frame(height: 4)
            .contentShape(Rectangle())
            .pointerStyle(.frameResize(position: edge == .top ? .top : .bottom))
            .gesture(dragGesture(entry: entry, drag: drag))
    }

    private func dragGesture(entry: TimeEntry, drag: CalendarLayout.Drag) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let range = CalendarLayout.result(
                    of: drag,
                    delta: CalendarLayout.duration(ofDistance: value.translation.height, hourHeight: hourHeight),
                    pointer: date(atY: value.location.y),
                    day: interval,
                    latestStart: entry.isRunning ? .now : nil
                )
                preview = Preview(id: entry.id, start: range.start, end: range.end)
            }
            .onEnded { _ in
                if let preview { commit(entry, start: preview.start, end: preview.end) }
                preview = nil
            }
    }

    private func newEntryPreview(_ preview: Preview, width: CGFloat) -> some View {
        let y = CalendarLayout.offset(of: preview.start, from: day, hourHeight: hourHeight)
        let height = CalendarLayout.offset(of: preview.end, from: day, hourHeight: hourHeight) - y
        let start = preview.start.formatted(date: .omitted, time: .shortened)
        let end = preview.end.formatted(date: .omitted, time: .shortened)
        return RoundedRectangle(cornerRadius: 5)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 5))
            .overlay(alignment: .topLeading) {
                Text("\(start)–\(end)").font(.caption.monospacedDigit()).padding(6)
            }
            .frame(width: width - 3, height: height)
            .offset(x: 4, y: y)
            .allowsHitTesting(false)
    }

    private func nowLine(_ now: Date, width: CGFloat) -> some View {
        let y = CalendarLayout.offset(of: now, from: day, hourHeight: hourHeight)
        return HStack(spacing: 0) {
            Circle().fill(.red).frame(width: 8, height: 8)
            Rectangle().fill(.red).frame(height: 1.5)
        }
        .frame(width: width + 8)
        .offset(x: -4, y: y - 4)
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    private func date(atY y: CGFloat) -> Date {
        CalendarLayout.date(atOffset: y, from: day, hourHeight: hourHeight)
    }

    private func initialHour(entries: [TimeEntry], now: Date) -> Int {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return max(0, calendar.component(.hour, from: now) - 3) }
        if let first = entries.first(where: { $0.start >= day }) { return max(0, calendar.component(.hour, from: first.start) - 1) }
        return 8
    }

    /// Applies a drag. The running entry keeps running: only its start can change.
    private func commit(_ entry: TimeEntry, start: Date, end: Date) {
        var draft = EntryDraft(entry: entry)
        draft.start = start
        if !entry.isRunning { draft.end = end }
        guard draft.validationError(now: .now) == nil else { return }
        perform { try TimerService(context: modelContext).save(draft, to: entry) }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            Log.timer.error("Calendar action failed: \(String(describing: error), privacy: .public)")
        }
    }
}

/// One entry on the timeline: tinted in its project color, like Toggl. The text adapts to the
/// block's height: two lines, one line, or none (the tooltip always has the details).
private struct CalendarBlock: View {
    let entry: TimeEntry
    let start: Date
    let end: Date
    let now: Date
    let height: CGFloat
    let isDragging: Bool

    private static let twoLineHeight: CGFloat = 32
    private static let oneLineHeight: CGFloat = 15

    var body: some View {
        let color = Color(hex: entry.project?.colorHex ?? HexColor.fallback)
        let shape = RoundedRectangle(cornerRadius: height < 8 ? 2 : 5)

        HStack(spacing: 0) {
            Rectangle().fill(color).frame(width: 3)
            content(color: color)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, height >= Self.twoLineHeight ? 3 : 0)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: height >= Self.twoLineHeight ? .top : .center)
        .background(color.opacity(entry.isRunning ? 0.14 : 0.26), in: shape)
        .overlay {
            if entry.isRunning {
                shape.strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(isDragging ? 0.25 : 0), radius: 6, y: 2)
    }

    @ViewBuilder
    private func content(color: Color) -> some View {
        if height >= Self.twoLineHeight {
            VStack(alignment: .leading, spacing: 1) {
                titleLine(color: color)
                durationText
            }
        } else if height >= Self.oneLineHeight {
            HStack(spacing: 6) {
                titleLine(color: color)
                durationText
            }
        }
    }

    private func titleLine(color: Color) -> some View {
        HStack(spacing: 6) {
            Text(entry.entryDescription.isEmpty ? "No description" : entry.entryDescription)
                .fontWeight(.semibold)
                .foregroundStyle(entry.entryDescription.isEmpty ? .secondary : .primary)
            if let project = entry.project {
                Text(project.name).foregroundStyle(color)
            }
        }
        .lineLimit(1)
    }

    private var durationText: some View {
        Text(isDragging ? timeRange : DurationFormat.clock(entry.isRunning ? entry.duration(at: now) : end.timeIntervalSince(start)))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var timeRange: String {
        "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }
}
