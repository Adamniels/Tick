import SwiftData
import SwiftUI

/// Description, project and tags for a new timer.
struct StartTimerForm: View {
    let style: TimerControls.Style
    let onStart: (String, Project?, [Tag]) -> Void

    @State private var description = ""
    @State private var project: Project?
    @State private var tags: [Tag] = []
    @AppStorage(AppSettings.Key.pomodoroEnabled) private var usePomodoro = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch style {
            case .panel:
                stacked(startOnReturn: true)
            case .bar:
                // One row when the window has room, otherwise stacked like the panel.
                ViewThatFits(in: .horizontal) {
                    HStack {
                        descriptionField
                            .frame(minWidth: 200, idealWidth: 260)
                        ProjectPicker(selection: $project)
                            .fixedSize()
                        pomodoroToggle
                        startButton
                    }
                    stacked(startOnReturn: false)
                }
            }
            TagSelector(selection: $tags)
        }
    }

    private func stacked(startOnReturn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                descriptionField
                startButton.keyboardShortcut(startOnReturn ? .defaultAction : nil)
            }
            HStack {
                ProjectPicker(selection: $project)
                pomodoroToggle
            }
        }
    }

    private var descriptionField: some View {
        TextField("What are you working on?", text: $description)
            .textFieldStyle(.roundedBorder)
            .onSubmit(start)
    }

    private var startButton: some View {
        Button("Start", systemImage: "play.fill", action: start)
            .labelStyle(.iconOnly)
            .help("Start timer")
    }

    private var pomodoroToggle: some View {
        Toggle("🍅 Pomodoro", isOn: $usePomodoro)
            .toggleStyle(.checkbox)
            .fixedSize()
            .help("Run this timer in pomodoro blocks")
    }

    private func start() {
        onStart(description.trimmingCharacters(in: .whitespaces), project, tags)
        description = ""
        project = nil
        tags = []
    }
}
