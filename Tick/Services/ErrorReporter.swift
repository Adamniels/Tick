import Foundation
import Observation
import OSLog

/// Failed user actions (D39): logged, and shown until dismissed, as a banner in the menu bar panel
/// and an alert in the main window. One place instead of per-view `do/catch` that only logged.
@Observable final class ErrorReporter {
    private(set) var message: String?

    /// Runs `body`; on failure reports "<action> failed: <reason>".
    func run(_ action: String, _ body: () throws -> Void) {
        do {
            try body()
        } catch {
            report(error, while: action)
        }
    }

    func report(_ error: Error, while action: String) {
        Log.app.error("\(action, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        message = "\(action) failed: \(error.localizedDescription)"
    }

    func dismiss() {
        message = nil
    }
}
