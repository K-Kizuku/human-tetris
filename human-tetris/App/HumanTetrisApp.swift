//
//  HumanTetrisApp.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI
import SwiftData

@main
struct HumanTetrisApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            GameScore.self,
            Settings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(sharedModelContainer)
    }
}
