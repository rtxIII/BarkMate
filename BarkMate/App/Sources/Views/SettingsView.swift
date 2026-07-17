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

    @Query(sort: \Server.createdAt, order: .reverse)
    private var servers: [Server]

    // Hooks 徽标的弱代理信号:app 无法直接探测开发机上的 hook 是否装好,
    // 以"是否收到过 ≥1 条 agent 推送"作为可靠的设备端间接证据。
    @Query private var agentTasks: [AgentTask]

    @State private var timeSensitiveAlerts: Bool = true
    @State private var showSetupGuide: Bool = false
    @State private var showServerList: Bool = false

    @EnvironmentObject private var selectedTab: SelectedTab

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
                    MCSectionHeader("Servers", trailing: serversTrailing)
                    ForEach(servers) { server in
                        MCSettingRow(
                            title: server.name ?? server.address,
                            detail: serverDetail(server)
                        ) {
                            MCSettingStateBadge(serverBadgeLabel(server), color: serverBadgeColor(server))
                        }
                    }
                    Button { showServerList = true } label: {
                        MCSettingRow(
                            title: "Manage servers",
                            detail: "Add / remove / health check."
                        ) { MCSettingValue("open") }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-manage-servers")

                    MCSectionHeader("Agent behavior", trailing: "defaults")
                    MCSettingRow(
                        title: "Stale timeout",
                        detail: "Running > this window → auto-demote to History · Stale."
                    ) { MCSettingValue("30 min") }

                    MCSectionHeader("Alerts", trailing: "02 rules")
                    MCSettingRow(
                        title: "Time-Sensitive alerts",
                        detail: "wait_input · blocked · failed break quiet mode."
                    ) {
                        MCToggle(isOn: $timeSensitiveAlerts, label: "Time-Sensitive alerts")
                    }
                    MCSettingRow(
                        title: "Mute rules",
                        detail: "By agent_id / status / server. (Coming soon)"
                    ) { MCSettingValue("manage ›", tone: .dim) }
                    MCSettingRow(
                        title: "Alert sound",
                        detail: "Per-status override · default = system."
                    ) { MCSettingValue("default") }

                    MCSectionHeader("Hooks", trailing: "agent integration")
                    MCSettingRow(
                        title: "Auto-installed",
                        detail: hooksDetail
                    ) {
                        MCSettingStateBadge(hooksBadgeText, color: hooksBadgeColor)
                    }
                    Button { showSetupGuide = true } label: {
                        MCSettingRow(
                            title: "Re-run installer",
                            detail: "One-line script · re-detects ~/.claude · ~/.codex · ~/.opencode."
                        ) { MCSettingValue("open ›") }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-rerun-installer")

                    MCSectionHeader("Privacy", trailing: "local")
                    MCSettingRow(
                        title: "Analytics",
                        detail: "None. Summary prompts never leave iPhone."
                    ) { MCSettingValue("off", tone: .dim) }
                    MCSettingRow(
                        title: "Privacy policy",
                        detail: "Required by App Store · barkmate.app/privacy."
                    ) { MCSettingValue("view ›", tone: .dim) }

                    MCSectionHeader("Device", trailing: "APNs")
                    MCSettingRow(
                        title: "APNs token",
                        detail: tokenPreview
                    ) {
                        MCSettingStateBadge(
                            tokenStore.token() == nil ? "Missing" : "Registered",
                            color: tokenStore.token() == nil ? MissionControl.Color.magenta : MissionControl.Color.lime
                        )
                    }

                    MCSectionHeader("About", trailing: "v\(appVersion)")
                    MCSettingRow(
                        title: "Bark protocol reference",
                        detail: "github.com/Finb/Bark"
                    ) { MCSettingValue("open") }
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
            ? "Claude (Stop · Notification) · Codex (on_block) · OpenCode (event:*)."
            : "Run the install script on your machine to wire up Claude / Codex / OpenCode."
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

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
