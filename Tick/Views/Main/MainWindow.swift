import SwiftUI

/// The main window. M1 manages projects and tags, M2 adds settings; M4 adds entries, M5 statistics.
struct MainWindow: View {
    let onTestPopup: () -> Void

    enum Section: Hashable {
        case projects, tags, settings
    }

    @State private var selection: Section? = .projects

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Projects", systemImage: "folder").tag(Section.projects)
                Label("Tags", systemImage: "tag").tag(Section.tags)
                Label("Settings", systemImage: "gearshape").tag(Section.settings)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selection {
            case .projects: LabelListView<Project>(title: "Projects", noun: "project")
            case .tags: LabelListView<Tag>(title: "Tags", noun: "tag")
            case .settings: SettingsView(onTestPopup: onTestPopup)
            case nil: Text("Select a section").foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 560, minHeight: 360)
    }
}
