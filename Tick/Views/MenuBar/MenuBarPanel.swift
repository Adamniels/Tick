import OSLog
import SwiftData
import SwiftUI

/// The panel shown when clicking the menu bar item.
struct MenuBarPanel: View {
    let storageError: String?
    let onOpenMainWindow: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(PomodoroService.self) private var pomodoro
    @AppStorage(AppSettings.Key.pomodoroEnabled) private var usePomodoro = false
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]
    @Query(filter: #Predicate<PomodoroSession> { $0.endedAt == nil }, sort: \PomodoroSession.start, order: .reverse)
    private var activeSessions: [PomodoroSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let storageError {
                Label("Not saving: \(storageError)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .lineLimit(3)
            }

            let session = activeSessions.first
            if let entry = running.first {
                RunningTimerView(entry: entry) { perform { try $0.stop() } }
            } else if session?.phaseValue.isBreak != true {
                StartTimerForm { description, project, tags in
                    perform { try $0.start(description: description, project: project, tags: tags, usePomodoro: usePomodoro) }
                }
            }
            if let session {
                PomodoroStatusView(
                    session: session,
                    onStartNextBlock: { perform { try $0.startNextBlock(after: session) } },
                    onEnd: { perform { try $0.end() } }
                )
            }

            Divider()
            TodayEntriesView(
                onContinue: { entry in perform { try $0.continueEntry(entry, usePomodoro: usePomodoro) } },
                onDelete: { entry in
                    do {
                        try TimerService(context: modelContext).delete(entry)
                    } catch {
                        Log.timer.error("Delete failed: \(String(describing: error), privacy: .public)")
                    }
                }
            )
            Divider()

            HStack {
                Button("Open Tick", action: onOpenMainWindow)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: 340)
    }

    private func perform(_ action: (PomodoroService) throws -> Void) {
        do {
            try action(pomodoro)
        } catch {
            Log.timer.error("Timer action failed: \(String(describing: error), privacy: .public)")
        }
    }
}

private struct RunningTimerView: View {
    @Bindable var entry: TimeEntry
    let onStop: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                // Editable while running; saved by the context's autosave.
                TextField("No description", text: $entry.entryDescription)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .onChange(of: entry.entryDescription) { entry.updatedAt = .now }
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
                .buttonStyle(.borderedProminent)
                .help("Stop timer")
        }
    }
}
