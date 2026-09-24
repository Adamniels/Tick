import SwiftData
import SwiftUI

/// Description, project and tags for a new timer.
struct StartTimerForm: View {
    let onStart: (String, Project?, [Tag]) -> Void

    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.name)
    private var projects: [Project]
    @Query(filter: #Predicate<Tag> { !$0.isArchived }, sort: \Tag.name)
    private var tags: [Tag]

    @State private var description = ""
    @State private var project: Project?
    @State private var selectedTags: Set<Tag> = []
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
                projectPicker
                Toggle("🍅 Pomodoro", isOn: $usePomodoro)
                    .toggleStyle(.checkbox)
                    .help("Run this timer in pomodoro blocks")
            }

            if !tags.isEmpty {
                tagChips
            }
        }
    }

    private var projectPicker: some View {
        Picker("Project", selection: $project) {
            Text("No project").tag(Project?.none)
            ForEach(projects) { project in
                Label {
                    Text(project.name)
                } icon: {
                    Image(nsImage: .dot(hex: project.colorHex))
                }
                .tag(Optional(project))
            }
        }
    }

    private var tagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags) { tag in
                    TagChip(tag: tag, isSelected: selectedTags.contains(tag)) {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                }
            }
        }
    }

    private func start() {
        let chosenTags = tags.filter { selectedTags.contains($0) }
        onStart(description.trimmingCharacters(in: .whitespaces), project, chosenTags)
        description = ""
        project = nil
        selectedTags = []
    }
}

private struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                ColorDot(hex: tag.colorHex, diameter: 7)
                Text(tag.name).font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(isSelected ? Color(hex: tag.colorHex).opacity(0.3) : Color.secondary.opacity(0.1))
            )
            .overlay(Capsule().strokeBorder(isSelected ? Color(hex: tag.colorHex) : .clear))
        }
        .buttonStyle(.plain)
    }
}
