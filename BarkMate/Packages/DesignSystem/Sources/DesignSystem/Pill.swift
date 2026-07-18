//
//  Pill.swift
//  DesignSystem
//
//  小号大写胶囊标签。dark 模式用于深色 hero 卡内部。
//

import SwiftUI

public struct Pill: View {
    private let text: String
    private let dark: Bool

    public init(_ text: String, dark: Bool = false) {
        self.text = text
        self.dark = dark
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.7)
            .foregroundStyle(dark ? .white.opacity(0.72) : BarkTheme.Palette.ink.opacity(0.58))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                dark ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(BarkTheme.Palette.ink.opacity(0.08)),
                in: Capsule()
            )
    }
}

#Preview {
    HStack(spacing: 8) {
        Pill("agent")
        Pill("first push", dark: true)
        Pill("status: waiting")
    }
    .padding()
    .background(BarkTheme.Palette.paperHot)
}

// MARK: - Mission Control variant
//
// 给任意 Text/View 套上 Mission Control 风格 pill 外观:
//   - bodyMono(11pt) 字 + 0.8 字距 + uppercase
//   - inkSoft 字色 + 锐角 + 1pt ruleHot 描边
//
// 不修改 `Pill` 结构体本身,避免影响暖纸主题旧调用方。
//
// 用法:
//   Text("agent").mcPill()
//

extension View {
    /// Mission Control 风格 pill 包装(锐角 + ruleHot 描边 + bodyMono)。
    public func mcPill() -> some View {
        self
            .font(MissionControl.Font.bodyMono)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(MissionControl.Color.inkSoft)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                Rectangle()
                    .stroke(MissionControl.Color.ruleHot, lineWidth: MissionControl.Border.hairline)
            )
    }
}

#Preview("Mission Control pill") {
    HStack(spacing: 8) {
        Text("agent").mcPill()
        Text("first push").mcPill()
        Text("0420").mcPill()
    }
    .padding()
    .background(MissionControl.Color.void)
}
