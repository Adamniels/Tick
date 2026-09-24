import OSLog
import SwiftData
import SwiftUI

/// The status item: `● 0:42:13 Operation Rollout` while running, an icon when idle.
///
/// This view is alive for the app's whole lifetime, so it also resolves duplicate running
/// entries whenever their count changes: on launch, locally, or after a CloudKit import.
struct MenuBarLabel: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]

    private static let maxTitleLength = 24

    var body: some View {
        Group {
            if let entry = running.first {
                TimelineView(.periodic(from: entry.start, by: 1)) { context in
                    Text("\(Image(nsImage: .dot(hex: entry.project?.colorHex ?? HexColor.fallback))) \(title(for: entry, at: context.date))")
                        .monospacedDigit()
                }
            } else {
                Image(systemName: "stopwatch")
            }
        }
        .onChange(of: running.count, initial: true) { _, count in
            guard count > 1 else { return }
            do {
                try TimerService(context: modelContext).resolveDuplicateRunning()
            } catch {
                Log.timer.error("Resolving duplicate running entries failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func title(for entry: TimeEntry, at now: Date) -> String {
        let clock = DurationFormat.clock(entry.duration(at: now))
        let name = entry.project?.name ?? entry.entryDescription
        guard !name.isEmpty else { return clock }
        let shortName = name.count > Self.maxTitleLength ? name.prefix(Self.maxTitleLength - 1) + "…" : name
        return "\(clock) \(shortName)"
    }
}
