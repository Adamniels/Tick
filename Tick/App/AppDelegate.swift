import AppKit
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    let modelContainer: ModelContainer
    private let storageError: String?
    private var statusItemController: StatusItemController?
    private var mainWindowController: MainWindowController?

    override init() {
        let result = Persistence.makeContainer()
        modelContainer = result.container
        storageError = result.error.map { String(describing: $0) }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit test host needs no UI.
        guard !Persistence.isRunningTests else { return }

        let mainWindowController = MainWindowController(modelContainer: modelContainer)
        self.mainWindowController = mainWindowController
        statusItemController = StatusItemController(
            modelContainer: modelContainer,
            storageError: storageError,
            onOpenMainWindow: { mainWindowController.show() }
        )
    }
}
