import SwiftData
import SwiftUI

@main
struct TickApp: App {
    private let modelContainer: ModelContainer
    private let storageError: String?

    init() {
        let result = Persistence.makeContainer()
        modelContainer = result.container
        storageError = result.error.map { String(describing: $0) }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(storageError: storageError)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)

        Window("Tick", id: MainWindow.id) {
            MainWindow()
        }
        .defaultLaunchBehavior(.suppressed)
        .modelContainer(modelContainer)
    }
}
