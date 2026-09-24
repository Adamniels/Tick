//
//  TickApp.swift
//  Tick
//
//  Created by Adam Nielsen on 2026-09-24.
//

import SwiftUI
import SwiftData

@main
struct TickApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        // CloudKit is disabled until M1 replaces the template model (Item has no defaults, so CloudKit validation fails).
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
