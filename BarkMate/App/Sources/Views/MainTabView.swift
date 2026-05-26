//
//  MainTabView.swift
//  BarkMate
//
//  V0.3 Phase 3.0.3 — 5 tab 主框架:
//  Agents / Search / Setup / History / Settings。tint 用 ink 与 mock 一致。
//  Phase 3.1.8: tabs 由 AppTab 枚举驱动,允许子视图通过 SelectedTab 环境
//  对象切换 tab(空 Dashboard 的 CTA 跳 Setup)。
//  Phase 4.0: FirstLaunch onboarding —— 启动时若通知/APNs/server 任一异常,
//  自动落 Setup tab,让用户看到状态条与 curl 模板;后续状态恢复后不再自动切。
//

import SwiftUI
import Factory
import Store
import DesignSystem

enum AppTab: Hashable {
    case agents, search, setup, history, settings
}

@MainActor
final class SelectedTab: ObservableObject {
    @Published var current: AppTab = .agents
}

struct MainTabView: View {
    @StateObject private var selection = SelectedTab()
    @Injected(\.notificationStatusStore) private var statusStore: NotificationStatusStore
    @State private var appliedOnboardingRedirect: Bool = false

    var body: some View {
        TabView(selection: $selection.current) {
            NavigationStack {
                AgentDashboardView()
            }
            .tabItem { Label("Agents", systemImage: "rectangle.grid.2x2") }
            .tag(AppTab.agents)

            NavigationStack {
                SearchView()
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppTab.search)

            NavigationStack {
                SetupView()
            }
            .tabItem { Label("Setup", systemImage: "terminal") }
            .tag(AppTab.setup)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "clock") }
            .tag(AppTab.history)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .tint(BarkTheme.Palette.ink)
        .environmentObject(selection)
        .onAppear {
            applyOnboardingRedirectIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationStatusStore.didChangeNotification)) { _ in
            applyOnboardingRedirectIfNeeded()
        }
    }

    /// 仅在本进程生命周期内的"首次"看到非 ok 状态时切到 Setup。后续用户主动
    /// 切回 Agents 不会被打断;状态变 ok 后再次失败也不会重新打断。
    private func applyOnboardingRedirectIfNeeded() {
        guard !appliedOnboardingRedirect else { return }
        let status = statusStore.current()
        switch status.kind {
        case .authorizationDenied, .apnsRegistrationFailed, .serverUnreachable:
            selection.current = .setup
            appliedOnboardingRedirect = true
        case .ok, .unknown:
            break
        }
    }
}
