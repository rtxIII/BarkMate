//
//  SetupView.swift
//  BarkMate
//
//  V0.3 Phase 3.3 Setup tab。SetupHero + curl 模板卡 + FieldExplainer +
//  旧 Bark 兼容说明。curl 模板暂硬编码,Phase 4 (CurlTemplateBuilder) 接当前 server。
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

    @State private var copyConfirmed: Bool = false
    @State private var demoConfirmed: Bool = false
    @State private var status: NotificationStatus = .unknown
    @State private var navigateToServers: Bool = false

    private var curlText: String {
        let host = servers.first?.address.trimmingCharacters(in: .whitespaces) ?? "https://api.day.app"
        let key = servers.first?.key.isEmpty == false ? servers.first!.key : "<key>"
        return """
        curl -X POST "\(host.hasSuffix("/") ? host : host + "/")\(key)" \\
          -d "group=backend-refactor" \\
          -d "task_id=auth-migration-0420" \\
          -d "agent_status=running" \\
          -d "progress=3/8" \\
          -d "title=Refactoring auth middleware"
        """
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if let banner = bannerData {
                    NotificationStatusBanner(data: banner, onAction: handleBannerAction)
                }
                SetupHero()
                curlCard
                fieldsCard
                legacyCard
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .background(MockScreenBackground())
        .navigationTitle("Setup")
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

    private var bannerData: NotificationStatusBannerData? {
        switch status.kind {
        case .ok, .unknown:
            return nil
        case .authorizationDenied:
            return .init(
                kind: .authorizationDenied,
                detail: status.detail ?? "Open iOS Settings → BarkMate to allow notifications.",
                actionLabel: "Open"
            )
        case .apnsRegistrationFailed:
            return .init(
                kind: .apnsRegistrationFailed,
                detail: status.detail,
                actionLabel: "Servers"
            )
        case .serverUnreachable:
            return .init(
                kind: .serverUnreachable,
                detail: status.detail,
                actionLabel: "Servers"
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
        default:
            break
        }
    }

    private var curlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Pill("curl template")
            Text(curlText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 0.92, green: 0.94, blue: 0.91))
                .lineSpacing(3)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BarkTheme.Palette.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Button(copyConfirmed ? "Copied" : "Copy curl") { copyCurl() }
                    .buttonStyle(PrimaryCapsuleButtonStyle())
                Button(demoConfirmed ? "Sent ✓" : "Send demo push") {
                    sendDemoPush()
                }
                .buttonStyle(SecondaryCapsuleButtonStyle())
            }
        }
        .mockCardPadding()
    }

    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关键字段")
                .font(.headline.weight(.heavy))
            FieldExplainer(name: "group", value: "agent_id")
            FieldExplainer(name: "task_id", value: "同一任务的聚合键")
            FieldExplainer(name: "agent_status", value: "running / waiting_input / blocked / done / failed")
            FieldExplainer(name: "progress", value: "3/7 或 45%")
        }
        .mockCardPadding()
    }

    private var legacyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("旧 Bark 兼容")
                .font(.headline.weight(.heavy))
            Text("不带 agent_status 的推送会进入 History Timeline,不会污染 Active Agents。")
                .font(.subheadline)
                .foregroundStyle(BarkTheme.Palette.ink.opacity(0.62))
        }
        .mockCardPadding()
    }

    private func copyCurl() {
        #if canImport(UIKit)
        UIPasteboard.general.string = curlText
        #endif
        copyConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copyConfirmed = false
        }
    }

    /// Setup tab 的本地 demo push:与 Dashboard toolbar bolt 共用 DemoPushInjector,
    /// 让用户跑通"curl 之前先看 active 卡片"的体验,无需配置任何服务器。
    private func sendDemoPush() {
        DemoPushInjector.injectNextStep(into: modelContainer)
        DarwinNotification.post(.itemDidArrive)
        demoConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            demoConfirmed = false
        }
    }
}

private struct SetupHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Pill("first push", dark: true)
            Text("Send one push. Get one living card.")
                .font(BarkTheme.Typography.heroSerif(size: 36))
                .tracking(-2)
                .foregroundStyle(.white)
            Text("带上 agent_status 和 task_id,同一个任务会原地更新,而不是堆成消息流。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.66))
                .lineSpacing(3)
        }
        .padding(18)
        .heroBackground(decorationColor: BarkTheme.Palette.warningYellow.opacity(0.34))
    }
}
