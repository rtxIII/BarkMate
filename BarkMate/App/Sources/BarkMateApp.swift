//
//  BarkAgentApp.swift
//  BarkAgent
//

import SwiftUI
import SwiftData
import Factory
import Models
import Store
import DesignSystem

@main
struct BarkAgentApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Injected(\.sharedModelContainer) private var sharedModelContainer: ModelContainer

    init() {
        MissionControl.Font.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
