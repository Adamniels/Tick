import Foundation
import OSLog
import Security
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
            // One store file per CloudKit environment (D36); never the template's old default.store.
            let configuration = ModelConfiguration(
                storeName(forEnvironment: cloudKitEnvironment), schema: schema,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
            return (try ModelContainer(for: schema, configurations: configuration), nil)
        } catch {
            Log.storage.error("Could not open the synced store: \(String(describing: error), privacy: .public)")
            return (makeInMemoryContainer(), error)
        }
    }

    /// The CloudKit environment this build is signed for. Exported (Direct Distribution) builds carry
    /// `icloud-container-environment = Production`; Xcode's development builds carry none, which
    /// CloudKit treats as Development.
    static var cloudKitEnvironment: String {
        guard let task = SecTaskCreateFromSelf(nil) else { return "Development" }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-environment" as CFString, nil)
        return (value as? String) ?? (value as? [String])?.first ?? "Development"
    }

    /// Separate local stores per environment (D36): the mirroring would otherwise upload a
    /// development store's records (test data) into production the first time a release build opens it.
    /// Development keeps the original "Tick" store, so debug builds keep their data.
    nonisolated static func storeName(forEnvironment environment: String) -> String {
        environment == "Production" ? "Tick-Production" : "Tick"
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
