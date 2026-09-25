import SwiftUI

/// The scrollable 24-hour timeline of one day: grid, entry blocks, current-time line, and the
/// mouse interactions. It owns only interaction state (drag preview, scroll position); changes to
/// entries go out through the callbacks.
struct CalendarTimeline: View {
    let day: Date
    let hourHeight: CGFloat
    let entries: [TimeEntry]
    let now: Date
    let onEdit: (TimeEntry) -> Void
    /// A new entry was requested for this range (click or drag on empty space).
    let onCreate: (Date, Date) -> Void
    /// A block was moved or resized to this range.
    let onChange: (TimeEntry, Date, Date) -> Void
    let onContinue: (TimeEntry) -> Void
    let onDelete: (TimeEntry) -> Void

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

    private var interval: DateInterval { CalendarLayout.interval(ofDay: day, calendar: .current) }

    var body: some View {
        let byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let blocks = CalendarLayout.blocks(
            for: entries.map { .init(id: $0.id, start: $0.start, end: $0.end ?? now) }, in: interval
        )

        ScrollViewReader { proxy in
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    hourLabels
                    GeometryReader { geometry in
                        let width = geometry.size.width - 8
                        ZStack(alignment: .topLeading) {
                            background
                            ForEach(blocks) { block in
                                if let entry = byID[block.id] {
                                    blockView(entry: entry, block: block, width: width)
                                }
                            }
                            if let preview, preview.id == nil {
                                newEntryPreview(preview, width: width)
                            }
                            if Calendar.current.isDateInToday(day) {
                                nowLine(width: width)
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
                let hour = initialHour
                DispatchQueue.main.async { proxy.scrollTo(hour, anchor: .top) }
            }
        }
        // Zoom around the middle of the view: the time there stays there.
        .onChange(of: hourHeight) { oldHeight, newHeight in
            let offset = CalendarLayout.zoomedOffset(
                currentOffset: scroll.offset, viewportHeight: scroll.viewportHeight, inset: Self.inset,
                oldHourHeight: oldHeight, newHourHeight: newHeight
            )
            // After layout, so the taller or shorter content can be scrolled to.
            DispatchQueue.main.async { scrollPosition.scrollTo(y: offset) }
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
    private var background: some View {
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
            onCreate(start, min(start + 1800, interval.end))
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
                    if let preview { onCreate(preview.start, preview.end) }
                    preview = nil
                }
        )
    }

    private func blockView(entry: TimeEntry, block: CalendarLayout.Block, width: CGFloat) -> some View {
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
            .onTapGesture { onEdit(entry) }
            .gesture(
                dragGesture(entry: entry, drag: .move(start: block.start, end: block.end)),
                including: canMove ? .all : .subviews
            )
            .contextMenu {
                Button("Edit…") { onEdit(entry) }
                Button("Continue") { onContinue(entry) }
                Divider()
                Button("Delete…", role: .destructive) { onDelete(entry) }
            }
            .offset(x: columnWidth * CGFloat(block.column) + 4, y: y)
    }

    private static func tooltip(for entry: TimeEntry, start: Date, end: Date) -> String {
        let range = "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
        return "\(entry.displayLabel)\n\(range)"
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
                if let preview { onChange(entry, preview.start, preview.end) }
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

    private func nowLine(width: CGFloat) -> some View {
        let y = CalendarLayout.offset(of: now, from: day, hourHeight: hourHeight)
        return HStack(spacing: 0) {
            Circle().fill(.red).frame(width: 8, height: 8)
            Rectangle().fill(.red).frame(height: 1.5)
        }
        .frame(width: width + 8)
        .offset(x: -4, y: y - 4)
        .allowsHitTesting(false)
    }

    private func date(atY y: CGFloat) -> Date {
        CalendarLayout.date(atOffset: y, from: day, hourHeight: hourHeight)
    }

    /// Where the view opens: a little before now today, else just before the first entry.
    private var initialHour: Int {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return max(0, calendar.component(.hour, from: now) - 3) }
        if let first = entries.first(where: { $0.start >= day }) { return max(0, calendar.component(.hour, from: first.start) - 1) }
        return 8
    }
}
