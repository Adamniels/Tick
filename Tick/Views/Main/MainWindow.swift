import SwiftUI

/// The main window: entries, calendar, statistics, projects and tags, settings.
struct MainWindow: View {
    let onTestPopup: () -> Void

    enum Section: Hashable {
        case entries, calendar, statistics, projects, tags, settings
    }

    @State private var selection: Section? = .entries
    @Environment(ErrorReporter.self) private var errors

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Entries", systemImage: "list.bullet.rectangle").tag(Section.entries)
                Label("Calendar", systemImage: "calendar.day.timeline.left").tag(Section.calendar)
                Label("Statistics", systemImage: "chart.bar").tag(Section.statistics)
                Label("Projects", systemImage: "folder").tag(Section.projects)
                Label("Tags", systemImage: "tag").tag(Section.tags)
                Label("Settings", systemImage: "gearshape").tag(Section.settings)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selection {
            case .entries: EntriesView()
            case .calendar: CalendarView()
            case .statistics: StatsView()
            case .projects: LabelListView<Project>(title: "Projects", noun: "project")
            case .tags: LabelListView<Tag>(title: "Tags", noun: "tag")
            case .settings: SettingsView(onTestPopup: onTestPopup)
            case nil: Text("Select a section").foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 560, minHeight: 360)
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { errors.message != nil }, set: { if !$0 { errors.dismiss() } })
        ) {
            Button("OK", action: errors.dismiss)
        } message: {
            Text(errors.message ?? "")
        }
    }
}
