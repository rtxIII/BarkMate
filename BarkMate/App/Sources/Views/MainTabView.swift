//
//  MainTabView.swift
//  BarkAgent
//
//  V0.4 Phase 3.2 — Mission Control IA rewrite。
//  Tab 顺序:Agents / History / Search / Settings(无 Setup tab)。
//  Setup 收为 Settings 内的 "接入向导" 子页(NavigationLink push)。
//
//  V0.4 Day 9 修复:
//  原方案用系统 TabView + .toolbar(.hidden, for: .tabBar) + .safeAreaInset(MCTabBar)
//  在 iOS 26 上出现「TabView 子视图被推为 0 高度,MCTabBar 居中漂浮」的崩坏。
//  这里改成 ZStack 自管 selection:VStack 上层放 4 个 NavigationStack(用 .opacity
//  切换可见性,保留 view state),底部钉 MCTabBar。无系统 TabView 参与。
//

import SwiftUI
import Factory
import Store
import DesignSystem

enum AppTab: Hashable, CaseIterable {
    case agents, history, search, settings
}

/// SettingsView 内部的 deep link 目标。
enum SettingsDeepLink: Hashable {
    /// 自动 push 进 SetupView(接入向导)。
    case setupGuide
}

@MainActor
final class SelectedTab: ObservableObject {
    @Published var current: AppTab = .agents
    /// 跨 tab 跳转时夹带的深链请求。被目标 tab 消费后应清空。
    @Published var pendingDeepLink: SettingsDeepLink?

    /// 一次性跳到 Settings 并请求展开 Setup guide。
    func requestSetupGuide() {
        current = .settings
        pendingDeepLink = .setupGuide
    }
}

struct MainTabView: View {
    @StateObject private var selection = SelectedTab()
    @Injected(\.notificationStatusStore) private var statusStore: NotificationStatusStore
    @State private var appliedOnboardingRedirect: Bool = false

    private let tabItems: [MCTabBarItem<AppTab>] = [
        MCTabBarItem(id: .agents, glyph: "▦", label: "Agents"),
        MCTabBarItem(id: .history, glyph: "※", label: "History"),
        MCTabBarItem(id: .search, glyph: "⌕", label: "Search"),
        MCTabBarItem(id: .settings, glyph: "⚙", label: "Settings")
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabContent

            MCTabBar(
                items: tabItems,
                selection: $selection.current
            )
        }
        .background(MissionControl.Color.background)
        .environmentObject(selection)
        .onAppear {
            applyOnboardingRedirectIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationStatusStore.didChangeNotification)) { _ in
            applyOnboardingRedirectIfNeeded()
        }
    }

    /// 当前 tab 对应的 NavigationStack。切 tab 时丢弃旧导航栈,简单稳定。
    /// 后续若需要"切回保留栈状态",再回头改回 ZStack+opacity 方案,但要确认不重叠渲染。
    @ViewBuilder
    private var tabContent: some View {
        switch selection.current {
        case .agents:
            NavigationStack { AgentDashboardView() }
        case .history:
            NavigationStack { HistoryView() }
        case .search:
            NavigationStack { SearchView() }
        case .settings:
            NavigationStack { SettingsView() }
        }
    }

    /// 仅在本进程生命周期内的"首次"看到非 ok 状态时跳到 Settings + 自动展开 Setup guide。
    /// 后续用户主动切回 Agents 不会被打断;状态变 ok 后再次失败也不会重新打断。
    private func applyOnboardingRedirectIfNeeded() {
        guard !appliedOnboardingRedirect else { return }
        let status = statusStore.current()
        switch status.kind {
        case .authorizationDenied, .apnsRegistrationFailed, .serverUnreachable, .storageUnavailable:
            selection.requestSetupGuide()
            appliedOnboardingRedirect = true
        case .ok, .unknown:
            break
        }
    }
}
