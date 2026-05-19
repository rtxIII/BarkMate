//
//  MainTabView.swift
//  BarkMate
//
//  Phase 4-Core: 三 tab 主框架。Timeline / Search / Settings。
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ItemTimelineView()
            }
            .tabItem {
                Label("Timeline", systemImage: "tray")
            }

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
