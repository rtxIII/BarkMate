//
//  AgentAvatar.swift
//  DesignSystem
//
//  Agent 卡片左上角的方形大写首字母头像。
//

import SwiftUI

public struct AgentAvatar: View {
    private let text: String

    public init(text: String) {
        self.text = text
    }

    /// 从 agent name 中提取最多两段首字母,大写。
    public init(agentName: String) {
        let initials = agentName
            .split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == " " })
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
        self.text = initials.isEmpty ? "?" : initials
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(BarkTheme.Palette.ink, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

#Preview {
    HStack {
        AgentAvatar(agentName: "backend-refactor")
        AgentAvatar(agentName: "test_writer")
        AgentAvatar(text: "??")
    }
    .padding()
    .background(BarkTheme.Palette.paperHot)
}
