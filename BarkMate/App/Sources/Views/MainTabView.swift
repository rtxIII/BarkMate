//
//  MainTabView.swift
//  BarkAgent
//
//  V0.4 Phase 3.2 — Mission Control IA rewrite。
//  Tab 顺序:Agents / History / Settings(无 Setup/Search tab)。
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
    case agents, history, settings
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

    /// 前台收到推送时的瞬态提示文案(nil = 不显示)。约 2s 自隐。
    @State private var pushToast: String?
    @State private var pushToastHideTask: DispatchWorkItem?

    private let tabItems: [MCTabBarItem<AppTab>] = [
        MCTabBarItem(id: .agents, glyph: "▦", label: "Agents"),
        MCTabBarItem(id: .history, glyph: "※", label: "History"),
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
        .overlay(alignment: .top) {
            if let pushToast {
                pushToastView(pushToast)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: pushToast)
        .onAppear {
            applyOnboardingRedirectIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationStatusStore.didChangeNotification)) { _ in
            applyOnboardingRedirectIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppDelegate.foregroundPushDidArrive)) { note in
            let message = note.userInfo?[AppDelegate.foregroundPushMessageKey] as? String
            showPushToast(message)
        }
    }

    /// 前台推送到达 toast:顶部滑入 cyan 色 `[ PUSH ] <标题>`,约 2s 自隐。
    private func pushToastView(_ message: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("[ PUSH ]")
                    .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(MissionControl.Color.cyan)
                Text(message)
                    .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                    .foregroundStyle(MissionControl.Color.ink)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .background(MissionControl.Color.hull)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(MissionControl.Color.cyan)
                .frame(width: MissionControl.Border.statusMarker)
                .shadow(color: MissionControl.Color.cyanGlow, radius: 12, x: 0, y: 0)
        }
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.cyan, lineWidth: MissionControl.Border.hairline)
        )
    }

    private func showPushToast(_ message: String?) {
        pushToast = message ?? "New push received."
        pushToastHideTask?.cancel()
        let task = DispatchWorkItem { pushToast = nil }
        pushToastHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: task)
    }

    /// 当前 tab 对应的 NavigationStack。切 tab 时丢弃旧导航栈,简单稳定。
    /// 后续若需要"切回保留栈状态",再回头改回 ZStack+opacity 方案,但要确认不重叠渲染。
    @ViewBuilder
    private var tabContent: some View {
        switch selection.current {
        case .agents:
            NavigationStack { AgentDashboardView().enableInteractivePopGesture() }
        case .history:
            NavigationStack { HistoryView().enableInteractivePopGesture() }
        case .settings:
            NavigationStack { SettingsView().enableInteractivePopGesture() }
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

// MARK: - 边缘返回手势恢复

/// 各 push 详情页都用 `.toolbar(.hidden, for: .navigationBar)` 隐藏了系统导航栏,
/// 而 UIKit 在隐藏导航栏时会自动禁用 `interactivePopGestureRecognizer`(从左边缘右滑返回)。
/// 这里把该手势的 delegate 接管回来:仅当栈内有上一页时才允许触发,根页面不误触。
extension View {
    func enableInteractivePopGesture() -> some View {
        background(InteractivePopGestureEnabler())
    }
}

private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        ProxyViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    /// 持有 delegate 引用(手势的 delegate 是 weak,需要有人强持有)。
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }

    /// 0×0 代理 VC:进入导航层级后接管边缘返回手势的 delegate。
    private final class ProxyViewController: UIViewController {
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            guard let navigationController else { return }
            coordinator.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.delegate = coordinator
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
