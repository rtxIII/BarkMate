//
//  SettingsView.swift
//  BarkMate
//
//  Phase 4-Core: 设置入口。当前仅 Servers 子页 + 版本信息；Phase 4 二轮可加加密配置/分组静音/导出。
//

import SwiftUI
import Factory
import Store

struct SettingsView: View {

    @Injected(\.deviceTokenStore) private var tokenStore: DeviceTokenStore

    var body: some View {
        Form {
            Section("Servers") {
                NavigationLink {
                    ServerListView()
                } label: {
                    Label("Manage servers", systemImage: "server.rack")
                }
            }

            Section("Device") {
                LabeledContent("APNs token") {
                    Text(tokenPreview)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                if let url = URL(string: "https://github.com/Finb/Bark") {
                    Link(destination: url) {
                        Label("Bark protocol reference", systemImage: "link")
                    }
                }
            }
        }
        .navigationTitle("Settings")
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
