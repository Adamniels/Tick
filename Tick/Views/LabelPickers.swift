import SwiftData
import SwiftUI

/// Project picker with colored dots. Archived projects are hidden, except `alwaysInclude`
/// (an edited entry's current project), so its current value can still be shown.
struct ProjectPicker: View {
    @Binding var selection: Project?
    var alwaysInclude: Project?

    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.name)
    private var activeProjects: [Project]

    var body: some View {
        Picker("Project", selection: $selection) {
            Text("No project").tag(Project?.none)
            ForEach(options) { project in
                Label {
                    Text(project.isArchived ? "\(project.name) (archived)" : project.name)
                } icon: {
                    Image(nsImage: .dot(hex: project.colorHex))
                }
                .tag(Optional(project))
            }
        }
    }

    private var options: [Project] {
        guard let extra = alwaysInclude, !activeProjects.contains(extra) else { return activeProjects }
        return activeProjects + [extra]
    }
}

/// Toggleable tag chips in a horizontal row. Archived tags are hidden unless already selected.
struct TagSelector: View {
    @Binding var selection: [Tag]

    @Query(sort: \Tag.name) private var allTags: [Tag]

    var body: some View {
        let visible = allTags.filter { !$0.isArchived || selection.contains($0) }
        if !visible.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(visible) { tag in
                        TagChip(tag: tag, isSelected: selection.contains(tag)) { toggle(tag) }
                    }
                }
            }
        }
    }

    private func toggle(_ tag: Tag) {
        if let index = selection.firstIndex(of: tag) {
            selection.remove(at: index)
        } else {
            selection.append(tag)
        }
    }
}

struct TagChip: View {
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
