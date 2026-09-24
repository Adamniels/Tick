import SwiftUI

/// The main window: entries, projects and tags, settings. M5 adds statistics.
struct MainWindow: View {
    let onTestPopup: () -> Void

    enum Section: Hashable {
        case entries, projects, tags, settings
    }

    @State private var selection: Section? = .entries

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Entries", systemImage: "list.bullet.rectangle").tag(Section.entries)
                Label("Projects", systemImage: "folder").tag(Section.projects)
                Label("Tags", systemImage: "tag").tag(Section.tags)
                Label("Settings", systemImage: "gearshape").tag(Section.settings)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selection {
            case .entries: EntriesView()
            case .projects: LabelListView<Project>(title: "Projects", noun: "project")
            case .tags: LabelListView<Tag>(title: "Tags", noun: "tag")
            case .settings: SettingsView(onTestPopup: onTestPopup)
            case nil: Text("Select a section").foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 560, minHeight: 360)
    }
}
