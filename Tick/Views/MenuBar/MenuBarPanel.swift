import SwiftData
import SwiftUI

/// The panel shown when clicking the menu bar item.
struct MenuBarPanel: View {
    let storageError: String?
    let onOpenMainWindow: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingService.self) private var tracking
    @Environment(PomodoroService.self) private var pomodoro
    @Environment(ErrorReporter.self) private var errors
    @AppStorage(AppSettings.Key.pomodoroEnabled) private var usePomodoro = false
    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var running: [TimeEntry]
    @Query(filter: #Predicate<PomodoroSession> { $0.endedAt == nil }, sort: \PomodoroSession.start, order: .reverse)
    private var activeSessions: [PomodoroSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = errors.message {
                HStack(alignment: .top) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .lineLimit(3)
                    Spacer()
                    Button("Dismiss", systemImage: "xmark", action: errors.dismiss)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
            }
            if let storageError {
                Label("Not saving: \(storageError)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .lineLimit(3)
            }

            let session = activeSessions.first
            if let entry = running.first {
                RunningTimerView(entry: entry) { errors.run("Stopping the timer") { try tracking.stop() } }
                    .id(entry.id)  // Fresh edit state per entry; a pending edit lands on its own entry.
            } else if session?.phaseValue.isBreak != true {
                StartTimerForm { description, project, tags in
                    errors.run("Starting the timer") {
                        try tracking.start(description: description, project: project, tags: tags, usePomodoro: usePomodoro)
                    }
                }
            }
            if let session {
                PomodoroStatusView(
                    session: session,
                    onStartNextBlock: { errors.run("Starting the next block") { try pomodoro.startNextBlock(after: session) } },
                    onEnd: { errors.run("Ending the pomodoro") { try pomodoro.end() } }
                )
            }

            Divider()
            TodayEntriesView(
                onContinue: { entry in
                    errors.run("Continuing the entry") { try tracking.continueEntry(entry, usePomodoro: usePomodoro) }
                },
                onDelete: { entry in
                    errors.run("Deleting the entry") { try TimerService(context: modelContext).delete(entry) }
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

}

private struct RunningTimerView: View {
    let entry: TimeEntry
    let onStop: () -> Void

    /// Edits are applied on Return, when focus leaves, or when the panel closes, not per keystroke,
    /// so the menu bar title (and the popover anchored to it) doesn't change while typing (D24).
    @State private var draft = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("No description", text: $draft)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .focused($isEditing)
                    .onSubmit(apply)
                    .onChange(of: isEditing) { _, editing in if !editing { apply() } }
                    .onDisappear(perform: apply)
                    .onAppear { draft = entry.entryDescription }
                    // Follow changes synced from another Mac, unless mid-edit.
                    .onChange(of: entry.entryDescription) { _, new in if !isEditing { draft = new } }
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
            Button("Stop", systemImage: "stop.fill") {
                apply()
                onStop()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .help("Stop timer")
        }
    }

    private func apply() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard trimmed != entry.entryDescription else { return }
        entry.entryDescription = trimmed
        entry.updatedAt = .now
    }
}
