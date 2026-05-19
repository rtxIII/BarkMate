//
//  BarkMateApp.swift
//  BarkMate
//

import SwiftUI
import SwiftData
import Factory
import Models
import Store

@main
struct BarkMateApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Injected(\.sharedModelContainer) private var sharedModelContainer: ModelContainer

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
