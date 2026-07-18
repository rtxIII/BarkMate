//
//  SetupView.swift
//  BarkAgent
//
//  V0.4 Day 8 — Mission Control 重写。
//  MCConsoleHeader + MCBanner + MCSetupHero + MCCodeBlock + MCFieldKey + 双按钮行。
//  数据流(@Query Server / @Injected NotificationStatusStore / DemoPushInjector)保持不变。
//

import SwiftUI
import SwiftData
import Factory
import Models
import Store
import BarkService
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

struct SetupView: View {

    @Query(sort: \Server.createdAt, order: .reverse)
    private var servers: [Server]

    @Injected(\.sharedModelContainer) private var modelContainer: ModelContainer
    @Injected(\.notificationStatusStore) private var statusStore: NotificationStatusStore

    @Environment(\.dismiss) private var dismiss

    @State private var copyConfirmed: Bool = false
    @State private var demoConfirmed: Bool = false
    @State private var status: NotificationStatus = .unknown
    @State private var navigateToServers: Bool = false

    /// Mock B 的 install.sh + per-agent fallback 模板。`BARK_KEY` 自动注入用户首个 server 的 key。
    private var installText: String {
        let key = servers.first?.key.isEmpty == false ? servers.first!.key : "<key>"
        return """
        # detects ~/.claude, ~/.codex, ~/.opencode and installs hooks
        curl -fsSL "https://barkagent.we2.xyz/install.sh" \\
          | BARK_KEY=\(key) sh

        # or for one specific agent
        barkmate install --agent=claude --key=$BARK_KEY
        # supported: claude · codex · opencode · custom
        """
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MCConsoleHeader(
                    crumbs: ["SYS", "SETUP", "0001"],
                    title: "First ",
                    italicAccent: "push"
                ) {
                    MCIconButton("←") { dismiss() }
                }
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 14) {
                    if let banner = bannerData {
                        MCBanner(
                            tone: banner.tone,
                            title: banner.title,
                            detail: banner.detail,
                            actionLabel: banner.actionLabel,
                            action: handleBannerAction
                        )
                    }

                    MCSetupHero(
                        tag: "one-line install",
                        title: "One script.\nEvery ",
                        italicAccent: "agent",
                        subtitle: "跑一遍这段脚本,它会用你的 device key 自动配好 Claude Code / Codex / OpenCode 的 hook,自建 agent 留一个通用 bark-push 命令兼容。"
                    )

                    MCSectionHeader("Install script", trailing: "copy & run")
                    MCCodeBlock(installText, label: "$ shell")

                    HStack(spacing: 8) {
                        Button(copyConfirmed ? "Copied" : "Copy install", action: copyInstall)
                            .buttonStyle(MCPrimaryButtonStyle())
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("setup-copy-install")
                        Button(demoConfirmed ? "Sent ✓" : "Send test push", action: sendDemoPush)
                            .buttonStyle(MCGhostButtonStyle())
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("setup-send-test-push")
                    }

                    MCSectionHeader("Hook integrations", trailing: "supported agents")
                    MCFieldKey(entries: [
                        .init(key: "claude", value: "~/.claude/settings.json · SessionStart + Stop + Notification"),
                        .init(key: "codex", value: "~/.codex/hooks.toml · on_start + on_complete + on_block"),
                        .init(key: "opencode", value: "~/.opencode/agents/*.yaml · event:* webhook"),
                        .init(key: "custom", value: "/usr/local/bin/bark-push · POST agent_status/task_id/progress")
                    ])
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .mcScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToServers) {
            ServerListView()
        }
        .onAppear {
            status = statusStore.current()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationStatusStore.didChangeNotification)) { _ in
            status = statusStore.current()
        }
    }

    private struct BannerSpec {
        let tone: MCBanner.Tone
        let title: String
        let detail: String?
        let actionLabel: String?
    }

    private var bannerData: BannerSpec? {
        switch status.kind {
        case .ok, .unknown:
            return nil
        case .authorizationDenied:
            return BannerSpec(
                tone: .warning,
                title: "Notifications are off",
                detail: status.detail ?? "Open iOS Settings → BarkAgent to allow notifications.",
                actionLabel: "Open"
            )
        case .apnsRegistrationFailed:
            return BannerSpec(
                tone: .alert,
                title: "APNs registration failed",
                detail: status.detail,
                actionLabel: "Servers"
            )
        case .serverUnreachable:
            return BannerSpec(
                tone: .danger,
                title: "Server unreachable",
                detail: status.detail,
                actionLabel: "Servers"
            )
        case .storageUnavailable:
            return BannerSpec(
                tone: .danger,
                title: "Storage unavailable",
                detail: status.detail ?? "BarkAgent could not open its shared storage. Reinstall the app to recover.",
                actionLabel: "Help"
            )
        }
    }

    private func handleBannerAction() {
        switch status.kind {
        case .authorizationDenied:
            #if canImport(UIKit)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #endif
        case .apnsRegistrationFailed, .serverUnreachable:
            navigateToServers = true
        case .storageUnavailable:
            #if canImport(UIKit)
            if let url = URL(string: "https://github.com/rtx3/BarkAgent#shared-storage-unavailable") {
                UIApplication.shared.open(url)
            }
            #endif
        default:
            break
        }
    }

    private func copyInstall() {
        #if canImport(UIKit)
        UIPasteboard.general.string = installText
        #endif
        copyConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copyConfirmed = false
        }
    }

    /// Setup tab 的本地 demo push:与 Dashboard toolbar bolt 共用 DemoPushInjector。
    private func sendDemoPush() {
        DemoPushInjector.injectNextStep(into: modelContainer)
        DarwinNotification.post(.itemDidArrive)
        demoConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            demoConfirmed = false
        }
    }
}
