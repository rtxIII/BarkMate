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
    @State private var uninstallConfirmed: Bool = false
    @State private var demoConfirmed: Bool = false
    @State private var status: NotificationStatus = .unknown
    @State private var navigateToServers: Bool = false

    /// 用户首个 server 的 key,缺失时回落 `<key>`。
    private var barkKey: String {
        servers.first?.key.isEmpty == false ? servers.first!.key : "<key>"
    }

    /// 屏幕展示用的 install 模板 —— 顶部保留一行注释作为解说。
    private var installText: String {
        """
        # detects ~/.claude, ~/.codex, ~/.opencode and installs hooks
        curl -fsSL "https://barkagent.we2.xyz/install.sh" \\
          | BARK_KEY=\(barkKey) sh
        """
    }

    /// 拷贝到剪贴板的 install 命令 —— 去掉注释,粘进终端即可直接跑。
    private var installCommand: String {
        """
        curl -fsSL "https://barkagent.we2.xyz/install.sh" \\
          | BARK_KEY=\(barkKey) sh
        """
    }

    /// 卸载命令 —— 无注释,展示与拷贝同一份。反向清理 install.sh 装配的一切。
    private var uninstallText: String {
        "curl -fsSL \"https://barkagent.we2.xyz/uninstall.sh\" | sh"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MCConsoleHeader(
                    crumbs: ["SYS", "SETUP", "0001"],
                    title: ""
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

                    Text("拷贝下面这条命令,在终端跑一遍——它会用你的 device key 自动配好 Claude / Codex / OpenCode 的 hook。")
                        .font(MissionControl.Font.jetBrainsMono(size: 12, weight: .regular))
                        .lineSpacing(6)
                        .foregroundStyle(MissionControl.Color.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)

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

                    MCSectionHeader("Uninstall script", trailing: "copy & run")
                    MCCodeBlock(uninstallText, label: "$ shell")

                    Button(uninstallConfirmed ? "Copied" : "Copy uninstall", action: copyUninstall)
                        .buttonStyle(MCGhostButtonStyle())
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("setup-copy-uninstall")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .mcScreenBackground()
        .overlay(alignment: .bottom) {
            if demoConfirmed {
                demoToast
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: demoConfirmed)
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

    /// 前台发 demo push 后的瞬态确认。真实产物是长在 Agents tab 的一张卡,
    /// 此页看不到,故用 toast 点明"卡片已生成,去 Agents 看"。1.5s 随 demoConfirmed 自动隐去。
    private var demoToast: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("[ SENT ]")
                    .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(MissionControl.Color.lime)
                Text("Demo card added — check the Agents tab.")
                    .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                    .foregroundStyle(MissionControl.Color.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .background(MissionControl.Color.hull)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(MissionControl.Color.lime)
                .frame(width: MissionControl.Border.statusMarker)
                .shadow(color: MissionControl.Color.limeGlow, radius: 12, x: 0, y: 0)
        }
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.lime, lineWidth: MissionControl.Border.hairline)
        )
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
        UIPasteboard.general.string = installCommand
        #endif
        copyConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copyConfirmed = false
        }
    }

    private func copyUninstall() {
        #if canImport(UIKit)
        UIPasteboard.general.string = uninstallText
        #endif
        uninstallConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            uninstallConfirmed = false
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
