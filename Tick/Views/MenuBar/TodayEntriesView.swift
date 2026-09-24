import SwiftData
import SwiftUI

/// Today's entries with a daily total (decision D8c).
struct TodayEntriesView: View {
    let onContinue: (TimeEntry) -> Void
    let onDelete: (TimeEntry) -> Void

    // A fixed recent window filtered in memory, so the view stays correct across midnight
    // without rebuilding the query's date predicate.
    @Query private var recent: [TimeEntry]
    // A ScrollView has no height of its own in a popover, so it's sized to its measured content.
    @State private var listHeight: CGFloat = 0

    private static let maxListHeight: CGFloat = 260

    init(onContinue: @escaping (TimeEntry) -> Void, onDelete: @escaping (TimeEntry) -> Void) {
        self.onContinue = onContinue
        self.onDelete = onDelete
        var descriptor = FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.start, order: .reverse)])
        descriptor.fetchLimit = 100
        _recent = Query(descriptor)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let today = recent.filter { Calendar.current.isDate($0.start, inSameDayAs: context.date) }
            let total = today.reduce(0) { $0 + $1.duration(at: context.date) }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Today").font(.headline)
                    Spacer()
                    Text(DurationFormat.clock(total)).monospacedDigit().foregroundStyle(.secondary)
                }

                if today.isEmpty {
                    Text("Nothing tracked yet today.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(today) { entry in
                                EntryRow(
                                    entry: entry,
                                    now: context.date,
                                    onContinue: { onContinue(entry) },
                                    onDelete: { onDelete(entry) }
                                )
                            }
                        }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                    }
                    .frame(height: min(listHeight, Self.maxListHeight))
                }
            }
        }
    }
}

private struct EntryRow: View {
    let entry: TimeEntry
    let now: Date
    let onContinue: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            ColorDot(hex: entry.project?.colorHex ?? HexColor.fallback)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.entryDescription.isEmpty ? "No description" : entry.entryDescription)
                    .foregroundStyle(entry.entryDescription.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                if let project = entry.project {
                    Text(project.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(DurationFormat.clock(entry.duration(at: now)))
                .monospacedDigit()
                .foregroundStyle(entry.isRunning ? .primary : .secondary)
            // Shown only on hover, so a stray click can't start a timer.
            Button("Continue", systemImage: "play.fill", action: onContinue)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Continue: start a new timer like this one")
                .opacity(isHovering ? 1 : 0)
                .allowsHitTesting(isHovering)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Continue", action: onContinue)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
