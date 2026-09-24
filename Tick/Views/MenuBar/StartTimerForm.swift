import SwiftData
import SwiftUI

/// Description, project and tags for a new timer.
struct StartTimerForm: View {
    let onStart: (String, Project?, [Tag]) -> Void

    @State private var description = ""
    @State private var project: Project?
    @State private var tags: [Tag] = []
    @AppStorage(AppSettings.Key.pomodoroEnabled) private var usePomodoro = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("What are you working on?", text: $description)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(start)
                Button("Start", systemImage: "play.fill", action: start)
                    .labelStyle(.iconOnly)
                    .keyboardShortcut(.defaultAction)
                    .help("Start timer")
            }

            HStack {
                ProjectPicker(selection: $project)
                Toggle("🍅 Pomodoro", isOn: $usePomodoro)
                    .toggleStyle(.checkbox)
                    .help("Run this timer in pomodoro blocks")
            }

            TagSelector(selection: $tags)
        }
    }

    private func start() {
        onStart(description.trimmingCharacters(in: .whitespaces), project, tags)
        description = ""
        project = nil
        tags = []
    }
}
