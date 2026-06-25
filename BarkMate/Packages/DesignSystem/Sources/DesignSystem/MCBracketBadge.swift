//
//  MCBracketBadge.swift
//  DesignSystem
//
//  Mission Control 行内极简状态码徽章。
//
//  纯文字 `[ WAIT ]` + 1pt 描边方框,**无背景填充**。
//
//  与 `StatusBadge(status:, style: .missionControl)` 的区别:
//   - StatusBadge.missionControl → 带 mcGlow 底色填充 + 描边(更醒目)
//   - MCBracketBadge             → 纯描边轮廓(更轻盈),给 list row / 行内紧凑使用
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    `.r-row .code`、`.q-row .stat` 等行内位置使用
//

import SwiftUI
import Models

public struct MCBracketBadge: View {
    private let code: String
    private let color: Color

    /// 标准入口:由 AgentStatus 推导 code / color。
    public init(status: AgentStatus) {
        let render = MissionControl.Status.render(for: status)
        self.code = render.code
        self.color = render.color
    }

    /// 自由入口:供非 AgentStatus 场景(如 push 计数 `[ × 03 ]`)。
    public init(code: String, color: Color) {
        self.code = code
        self.color = color
    }

    public var body: some View {
        Text(code)
            .font(MissionControl.Font.bodyMono)
            .tracking(1.0)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(
                Rectangle()
                    .stroke(color, lineWidth: MissionControl.Border.hairline)
            )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        ForEach(AgentStatus.allCases, id: \.self) { status in
            HStack {
                MCBracketBadge(status: status)
                Text(status.label)
                    .font(MissionControl.Font.bodyS)
                    .foregroundStyle(MissionControl.Color.inkSoft)
            }
        }
        MCBracketBadge(code: "[ ×03 ]", color: MissionControl.Color.cyan)
        MCBracketBadge(code: "[ +07 ]", color: MissionControl.Color.lime)
    }
    .padding()
    .background(MissionControl.Color.void)
}
