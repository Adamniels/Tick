import CoreGraphics
import Foundation

/// Geometry of the calendar day view as pure functions (M7): where blocks go, how overlapping
/// entries share the width, and what a drag does to an entry's times.
nonisolated enum CalendarLayout {
    static let snapMinutes = 5
    static var minimumDuration: TimeInterval { TimeInterval(snapMinutes * 60) }

    struct Item: Equatable {
        let id: UUID
        let start: Date
        let end: Date
    }

    struct Block: Equatable, Identifiable {
        let id: UUID
        /// Clipped to the day.
        let start: Date
        let end: Date
        /// The entry started the day before or ends the day after.
        let continuesBefore: Bool
        let continuesAfter: Bool
        /// Overlapping entries share the width: this block takes column `column` of `columnCount`.
        let column: Int
        let columnCount: Int
    }

    /// Blocks for the entries inside `day`. Entries that overlap, directly or through a chain,
    /// form a cluster; within a cluster each entry takes the first free column.
    static func blocks(for items: [Item], in day: DateInterval) -> [Block] {
        let clipped = items
            .compactMap { item -> (item: Item, start: Date, end: Date)? in
                let start = max(item.start, day.start)
                let end = min(item.end, day.end)
                return end > start ? (item, start, end) : nil
            }
            .sorted { ($0.start, $0.item.id.uuidString) < ($1.start, $1.item.id.uuidString) }

        var result: [Block] = []
        var cluster: [(item: Item, start: Date, end: Date, column: Int)] = []
        var columnEnds: [Date] = []
        var clusterEnd = Date.distantPast

        func flushCluster() {
            for member in cluster {
                result.append(Block(
                    id: member.item.id, start: member.start, end: member.end,
                    continuesBefore: member.item.start < day.start, continuesAfter: member.item.end > day.end,
                    column: member.column, columnCount: max(1, columnEnds.count)
                ))
            }
            cluster = []
            columnEnds = []
        }

        for entry in clipped {
            if !cluster.isEmpty && entry.start >= clusterEnd {
                flushCluster()
            }
            let column = columnEnds.firstIndex { $0 <= entry.start } ?? columnEnds.count
            if column == columnEnds.count {
                columnEnds.append(entry.end)
            } else {
                columnEnds[column] = entry.end
            }
            clusterEnd = cluster.isEmpty ? entry.end : max(clusterEnd, entry.end)
            cluster.append((entry.item, entry.start, entry.end, column))
        }
        flushCluster()
        return result
    }

    // MARK: - Geometry

    static func offset(of date: Date, from dayStart: Date, hourHeight: CGFloat) -> CGFloat {
        CGFloat(date.timeIntervalSince(dayStart) / 3600) * hourHeight
    }

    static func date(atOffset offset: CGFloat, from dayStart: Date, hourHeight: CGFloat) -> Date {
        dayStart + TimeInterval(offset / hourHeight * 3600)
    }

    static func duration(ofDistance distance: CGFloat, hourHeight: CGFloat) -> TimeInterval {
        TimeInterval(distance / hourHeight * 3600)
    }

    /// Rounds to the nearest snap step, counted from the start of the day.
    static func snapped(_ date: Date, from dayStart: Date) -> Date {
        let step = minimumDuration
        return dayStart + (date.timeIntervalSince(dayStart) / step).rounded() * step
    }

    // MARK: - Dragging

    enum Drag: Equatable {
        /// Dragging on empty space from `anchor`.
        case create(anchor: Date)
        case move(start: Date, end: Date)
        case resizeStart(start: Date, end: Date)
        case resizeEnd(start: Date, end: Date)
    }

    /// The times a drag results in: `delta` is how far the pointer moved (move and resize),
    /// `pointer` where it is now (create). Snapped, kept inside the day, and at least the minimum
    /// duration. `latestStart` keeps a running entry's start from passing now.
    static func result(
        of drag: Drag, delta: TimeInterval, pointer: Date, day: DateInterval, latestStart: Date? = nil
    ) -> (start: Date, end: Date) {
        let minimum = minimumDuration
        switch drag {
        case .create(let anchor):
            let a = snapped(clamp(anchor, day), from: day.start)
            let b = snapped(clamp(pointer, day), from: day.start)
            var start = min(a, b)
            var end = max(a, b)
            if end.timeIntervalSince(start) < minimum {
                end = start + minimum
                if end > day.end {
                    end = day.end
                    start = end - minimum
                }
            }
            return (start, end)

        case .move(let start, let end):
            let length = end.timeIntervalSince(start)
            let latest = day.end - length
            let newStart = max(day.start, min(snapped(start + delta, from: day.start), latest))
            return (newStart, newStart + length)

        case .resizeStart(let start, let end):
            var newStart = snapped(start + delta, from: day.start)
            newStart = min(newStart, end - minimum)
            if let latestStart { newStart = min(newStart, latestStart) }
            return (max(newStart, day.start), end)

        case .resizeEnd(let start, let end):
            let newEnd = snapped(end + delta, from: day.start)
            return (start, min(max(newEnd, start + minimum), day.end))
        }
    }

    private static func clamp(_ date: Date, _ day: DateInterval) -> Date {
        min(max(date, day.start), day.end)
    }
}
