//
//  SettingsView.swift
//  BarkAgent
//
//  V0.4 Day 8 — Mission Control 重写。
//  MCConsoleHeader + MCSectionHeader 分段 + MCSettingRow (含 MCToggle / MCSettingStateBadge).
//  数据流(@Query Server / DeviceTokenStore / SelectedTab.pendingDeepLink)保持不变。
//

import SwiftUI
import SwiftData
import Factory
import Models
import Store
import DesignSystem

struct SettingsView: View {

    @Injected(\.deviceTokenStore) private var tokenStore: DeviceTokenStore
    @Injected(\.alertSoundStore) private var alertSoundStore: AlertSoundStore
    @Injected(\.staleTimeoutStore) private var staleTimeoutStore: StaleTimeoutStore

    @Query(sort: \Server.createdAt, order: .reverse)
    private var servers: [Server]

    // Hooks 徽标的弱代理信号:app 无法直接探测开发机上的 hook 是否装好,
    // 以"是否收到过 ≥1 条 agent 推送"作为可靠的设备端间接证据。
    @Query private var agentTasks: [AgentTask]

    @State private var timeSensitiveAlerts: Bool = true
    @State private var showSetupGuide: Bool = false
    @State private var showServerList: Bool = false
    @State private var showSoundPicker: Bool = false
    @State private var showStalePicker: Bool = false

    @EnvironmentObject private var selectedTab: SelectedTab
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MCConsoleHeader(
                    crumbs: ["SYS", "SETTINGS", appVersion.uppercased()],
                    title: "Settings"
                ) {
                    MCIconButton("+") { showServerList = true }
                        .accessibilityIdentifier("settings-server-list-shortcut")
                }
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 0) {
                    // MARK: CONFIG — 就地操作 / 值选择,当场改设置
                    MCSectionHeader("Config", trailing: "adjust here")
                    MCSettingRow(
                        title: "Time-Sensitive alerts",
                        detail: "wait_input · blocked · failed break quiet mode."
                    ) {
                        MCToggle(isOn: $timeSensitiveAlerts, label: "Time-Sensitive alerts")
                    }
                    Button { showSoundPicker = true } label: {
                        MCSettingRow(
                            title: "Alert sound",
                            detail: "Per-status override · default = system."
                        ) { MCSettingValue(globalSoundLabel) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-alert-sound")
                    Button { showStalePicker = true } label: {
                        MCSettingRow(
                            title: "Stale timeout",
                            detail: "Running > this window → auto-demote to History · Stale."
                        ) { MCSettingValue(staleTimeoutStore.threshold().displayLabel) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-stale-timeout")

                    // MARK: STATUS — 只读,不操作也不跳转
                    MCSectionHeader("Status", trailing: serversTrailing)
                    ForEach(servers) { server in
                        MCSettingRow(
                            title: server.name ?? server.address,
                            detail: serverDetail(server)
                        ) {
                            MCSettingStateBadge(serverBadgeLabel(server), color: serverBadgeColor(server))
                        }
                    }
                    MCSettingRow(
                        title: "APNs token",
                        detail: tokenPreview
                    ) {
                        MCSettingStateBadge(
                            tokenStore.token() == nil ? "Missing" : "Registered",
                            color: tokenStore.token() == nil ? MissionControl.Color.magenta : MissionControl.Color.lime
                        )
                    }

                    // MARK: ROUTES — 跳转入口 & 外链
                    MCSectionHeader("Routes", trailing: "entries & links")
                    Button { showServerList = true } label: {
                        MCSettingRow(
                            title: "Manage servers",
                            detail: "Add / remove / health check."
                        ) { MCSettingValue("open") }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-manage-servers")
                    Button { showSetupGuide = true } label: {
                        MCSettingRow(
                            title: "Auto-installed",
                            detail: hooksDetail
                        ) {
                            MCSettingStateBadge(hooksBadgeText, color: hooksBadgeColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-rerun-installer")
                    Button { openURL(Self.privacyPolicyURL) } label: {
                        MCSettingRow(
                            title: "Privacy policy",
                            detail: "Required by App Store · barkagent.we2.xyz/privacy."
                        ) { MCSettingValue("view ›", tone: .dim) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-privacy-policy")
                    Button { openURL(Self.barkReferenceURL) } label: {
                        MCSettingRow(
                            title: "Bark protocol reference",
                            detail: "github.com/Finb/Bark"
                        ) { MCSettingValue("open") }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-bark-reference")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .mcScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showSetupGuide) {
            SetupView()
        }
        .navigationDestination(isPresented: $showServerList) {
            ServerListView()
        }
        .navigationDestination(isPresented: $showSoundPicker) {
            AlertSoundPickerView()
        }
        .navigationDestination(isPresented: $showStalePicker) {
            StaleTimeoutPickerView()
        }
        .onAppear { consumePendingDeepLinkIfNeeded() }
        .onChange(of: selectedTab.pendingDeepLink) { _, _ in
            consumePendingDeepLinkIfNeeded()
        }
    }

    /// 如果有从其它 tab 跳过来的 setupGuide 请求,自动 push 进 SetupView。
    /// 消费后清空请求,避免重复触发。
    private func consumePendingDeepLinkIfNeeded() {
        guard selectedTab.pendingDeepLink == .setupGuide else { return }
        showSetupGuide = true
        selectedTab.pendingDeepLink = nil
    }

    // MARK: - Hooks 徽标(弱代理信号)

    /// 收到过 ≥1 条 agent 推送即视为 hook 已在某处生效。
    private var hasReceivedAgentPush: Bool {
        !agentTasks.isEmpty
    }

    private var hooksBadgeText: String {
        hasReceivedAgentPush ? "active" : "setup"
    }

    private var hooksBadgeColor: Color {
        hasReceivedAgentPush ? MissionControl.Color.lime : MissionControl.Color.inkSoft
    }

    private var hooksDetail: String {
        hasReceivedAgentPush
            ? "Claude (Stop · Notification) · Codex (on_block) · OpenCode (event:*). Tap to re-run installer."
            : "Tap to run the one-line installer for Claude · Codex · OpenCode."
    }

    private var serversTrailing: String {
        let online = servers.filter { $0.state == .ok }.count
        return "\(online < 10 ? "0\(online)" : "\(online)") · apns ok"
    }

    private func serverDetail(_ server: Server) -> String {
        // mock B: "Default · APNs registered · last push 02m ago · 320 today"
        // 实际 server 数据没 lastPushAt/todayCount, 只能展示已有字段。
        let apns = server.key.isEmpty ? "APNs not yet registered" : "APNs registered"
        if let last = server.lastSyncedAt {
            return "\(apns) · checked \(AgentCardData.relativeLabel(from: last)) ago"
        }
        return apns
    }

    private func serverBadgeLabel(_ server: Server) -> String {
        switch server.state {
        case .ok: return "On"
        case .error: return "Off"
        default: return "Pending"
        }
    }

    private func serverBadgeColor(_ server: Server) -> Color {
        switch server.state {
        case .ok: return MissionControl.Color.lime
        case .error: return MissionControl.Color.magenta
        default: return MissionControl.Color.amber
        }
    }

    private var tokenPreview: String {
        guard let token = tokenStore.token() else { return "Not yet registered" }
        if token.count <= 16 { return token }
        return "\(token.prefix(8))…\(token.suffix(8))"
    }

    private var globalSoundLabel: String {
        guard
            let id = alertSoundStore.globalDefaultID(),
            let sound = SoundCatalog.sound(for: id)
        else { return "default" }
        return sound.displayName.lowercased()
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    // 外链目标。硬编码值集中在此,避免散落 view body。
    private static let privacyPolicyURL = URL(string: "https://barkagent.we2.xyz/privacy")!
    private static let barkReferenceURL = URL(string: "https://github.com/Finb/Bark")!
}
