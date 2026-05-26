//
//  SettingsView.swift
//  BarkMate
//
//  V0.3 Phase 3.6 Settings tab。paperHot 卡 + SettingRow + Agent behavior +
//  LiveActivity 概念预告。Servers section 复用 ServerListView 数据源。
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

    @State private var onDeviceSummary: Bool = true
    @State private var timeSensitiveAlerts: Bool = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Servers", trailing: serversTrailing)
                ForEach(servers) { server in
                    SettingRow(
                        title: server.name ?? server.address,
                        detail: serverDetail(server),
                        badge: server.state == .ok ? "online" : (server.state == .error ? "offline" : "pending")
                    )
                }
                NavigationLink {
                    ServerListView()
                } label: {
                    SettingRow(
                        title: "Manage servers",
                        detail: "Add / remove / health check",
                        badge: "open"
                    )
                }
                .buttonStyle(.plain)

                SectionTitle("Agent behavior", trailing: "defaults")
                SettingRow(
                    title: "Stale timeout",
                    detail: "Running tasks become stale after 30 minutes.",
                    badge: "30m"
                )
                SettingToggleRow(
                    title: "On-device summary",
                    detail: "Use Apple Intelligence when available.",
                    isOn: $onDeviceSummary
                )
                SettingToggleRow(
                    title: "Time Sensitive alerts",
                    detail: "waiting_input, blocked and failed can break through quiet mode.",
                    isOn: $timeSensitiveAlerts
                )
                SettingRow(
                    title: "Privacy",
                    detail: "No analytics. Summary prompts never leave iPhone.",
                    badge: "local"
                )

                SectionTitle("Device", trailing: "APNs")
                SettingRow(
                    title: "APNs token",
                    detail: tokenPreview,
                    badge: tokenStore.token() == nil ? "missing" : "registered"
                )

                SectionTitle("About", trailing: "v\(appVersion)")
                SettingRow(
                    title: "Bark protocol reference",
                    detail: "github.com/Finb/Bark",
                    badge: "open"
                )

                SectionTitle("Live Activity concept", trailing: "V1.1")
                LiveActivityPreviewCard()
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .background(MockScreenBackground())
        .navigationTitle("Settings")
    }

    private var serversTrailing: String {
        let online = servers.filter { $0.state == .ok }.count
        return "\(online) online"
    }

    private func serverDetail(_ server: Server) -> String {
        let key = server.key.isEmpty ? "no key" : "key synced"
        if let last = server.lastSyncedAt {
            return "\(key) · checked \(AgentCardData.relativeLabel(from: last)) ago"
        }
        return key
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

private struct LiveActivityPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                AgentAvatar(agentName: "test-writer")
                VStack(alignment: .leading, spacing: 2) {
                    Text("test-writer needs confirmation")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("Confirm overwrite existing mocks · 4/7 complete")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                StatusBadge(status: .waitingInput, compact: true)
            }
            ProgressView(value: 4.0 / 7.0)
                .tint(BarkTheme.Palette.warningYellow)
        }
        .padding(15)
        .background(
            LinearGradient(
                colors: [BarkTheme.Palette.ink, BarkTheme.Palette.inkDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }
}
