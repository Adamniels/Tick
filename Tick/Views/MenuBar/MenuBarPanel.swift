import OSLog
import SwiftData
import SwiftUI

/// The panel shown when clicking the menu bar item.
struct MenuBarPanel: View {
    let storageError: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let storageError {
                Label("Not saving: \(storageError)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .lineLimit(3)
            }

            if let entry = running.first {
                RunningTimerView(entry: entry) { perform { try $0.stop() } }
            } else {
                StartTimerForm { description, project, tags in
                    perform { try $0.start(description: description, project: project, tags: tags) }
                }
            }

            Divider()
            TodayEntriesView { entry in perform { try $0.continueEntry(entry) } }
            Divider()

            HStack {
                Button("Open Tick") {
                    openWindow(id: MainWindow.id)
                    NSApp.activate()
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: 340)
    }

    private func perform(_ action: (TimerService) throws -> Void) {
        do {
            try action(TimerService(context: modelContext))
        } catch {
            Log.timer.error("Timer action failed: \(String(describing: error), privacy: .public)")
        }
    }
}

private struct RunningTimerView: View {
    let entry: TimeEntry
    let onStop: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.entryDescription.isEmpty ? "No description" : entry.entryDescription)
                    .foregroundStyle(entry.entryDescription.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                if let project = entry.project {
                    HStack(spacing: 4) {
                        ColorDot(hex: project.colorHex)
                        Text(project.name).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            TimelineView(.periodic(from: entry.start, by: 1)) { context in
                Text(DurationFormat.clock(entry.duration(at: context.date)))
                    .font(.title3.monospacedDigit())
            }
            Button("Stop", systemImage: "stop.fill", action: onStop)
                .labelStyle(.iconOnly)
                .keyboardShortcut(.defaultAction)
                .help("Stop timer")
        }
    }
}
