import OSLog
import Foundation
import SwiftData

/// Builds the app's `ModelContainer`: synced via CloudKit normally, in-memory when hosting unit tests.
enum Persistence {
    static let cloudKitContainerID = "iCloud.com.adamniels.Tick"
    static let schema = Schema([Project.self, Tag.self, TimeEntry.self, PomodoroSession.self])

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// If the synced store can't be opened, the app falls back to an in-memory store
    /// and returns the error so the UI can say that nothing is being saved.
    static func makeContainer() -> (container: ModelContainer, error: Error?) {
        if isRunningTests {
            return (makeInMemoryContainer(), nil)
        }
        do {
            // Named store, so the template's old default.store is never opened with the new schema.
            let configuration = ModelConfiguration("Tick", schema: schema, cloudKitDatabase: .private(cloudKitContainerID))
            return (try ModelContainer(for: schema, configurations: configuration), nil)
        } catch {
            Log.storage.error("Could not open the synced store: \(String(describing: error), privacy: .public)")
            return (makeInMemoryContainer(), error)
        }
    }

    /// A fresh, isolated in-memory container without CloudKit.
    static func makeInMemoryContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            UUID().uuidString, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        )
        // Cannot fail for a valid schema; failing here is a programming error.
        return try! ModelContainer(for: schema, configurations: configuration)
    }
}
