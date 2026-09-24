import SwiftUI

/// The main window. M1 manages projects and tags; M4 adds entries, M5 statistics.
struct MainWindow: View {
    static let id = "main"

    enum Section: Hashable {
        case projects, tags
    }

    @State private var selection: Section? = .projects

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Projects", systemImage: "folder").tag(Section.projects)
                Label("Tags", systemImage: "tag").tag(Section.tags)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selection {
            case .projects: LabelListView<Project>(title: "Projects", noun: "project")
            case .tags: LabelListView<Tag>(title: "Tags", noun: "tag")
            case nil: Text("Select a section").foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 560, minHeight: 360)
    }
}
