import SwiftData
import SwiftUI

/// The panel shown when clicking the menu bar item.
struct MenuBarPanel: View {
    let storageError: String?
    let onOpenMainWindow: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingService.self) private var tracking
    @Environment(ErrorReporter.self) private var errors
    @AppStorage(AppSettings.Key.pomodoroEnabled) private var usePomodoro = false

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

            TimerControls(style: .panel)

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
