//
//  AgentAvatar.swift
//  DesignSystem
//
//  Agent 卡片左上角的方形大写首字母头像。
//
//  Mission Control 变体(`style: .missionControl`):
//   - 透明背景 + cyan 文字 + JetBrainsMono Bold,贴合 mock B `.r-row .av` 极简风
//   - 原 init(text:) / init(agentName:) 行为完全不变,旧调用方零影响
//

import SwiftUI

public struct AgentAvatar: View {
    public enum Style {
        case classic
        case missionControl
    }

    private let text: String
    private let style: Style

    public init(text: String) {
        self.text = text
        self.style = .classic
    }

    /// 从 agent name 中提取最多两段首字母,大写。
    public init(agentName: String) {
        self.text = Self.initials(from: agentName)
        self.style = .classic
    }

    public init(text: String, style: Style) {
        self.text = text
        self.style = style
    }

    public init(agentName: String, style: Style) {
        self.text = Self.initials(from: agentName)
        self.style = style
    }

    public var body: some View {
        switch style {
        case .classic: classicBody
        case .missionControl: missionControlBody
        }
    }

    private var classicBody: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(BarkTheme.Palette.ink, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var missionControlBody: some View {
        Text(text)
            .font(MissionControl.Font.jetBrainsMono(size: 13, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(MissionControl.Color.cyan)
            .frame(width: 28, height: 28)
            .background(Color.clear)
    }

    private static func initials(from agentName: String) -> String {
        let parts = agentName
            .split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == " " })
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
        return parts.isEmpty ? "?" : parts
    }
}

#Preview {
    HStack(spacing: 12) {
        AgentAvatar(agentName: "backend-refactor")
        AgentAvatar(agentName: "test_writer")
        AgentAvatar(text: "??")
    }
    .padding()
    .background(BarkTheme.Palette.paperHot)
}

#Preview("Mission Control") {
    HStack(spacing: 12) {
        AgentAvatar(agentName: "backend-refactor", style: .missionControl)
        AgentAvatar(agentName: "test_writer", style: .missionControl)
        AgentAvatar(text: "??", style: .missionControl)
    }
    .padding()
    .background(MissionControl.Color.void)
}
