//
//  MCIconButton.swift
//  DesignSystem
//
//  Mission Control 32×32 方角图标按钮。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .ic-btn        L452  32×32 grid place-items center
//    .ic-btn        L457  1pt ruleHot 描边 + hull 背景 + 13pt 700 ink
//    .ic-btn:hover  L465  amber 背景 + void 文字 + amber 边框
//
//  状态映射:
//    - normal       → hull / ruleHot / ink
//    - pressed      → amber / amber / void(:hover 等价)
//    - isActive=true → 与 pressed 同视觉(供持续高亮使用,如焦点态)
//

import SwiftUI

public struct MCIconButton: View {
    private let glyph: String
    private let isActive: Bool
    private let action: () -> Void

    public init(_ glyph: String, isActive: Bool = false, action: @escaping () -> Void = {}) {
        self.glyph = glyph
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(glyph)
        }
        .buttonStyle(MCIconButtonStyle(isActive: isActive))
    }
}

private struct MCIconButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let highlighted = isActive || configuration.isPressed
        return configuration.label
            .font(MissionControl.Font.jetBrainsMono(size: 13, weight: .bold))
            .foregroundStyle(highlighted ? MissionControl.Color.void : MissionControl.Color.ink)
            .frame(width: 32, height: 32)
            .background(highlighted ? MissionControl.Color.amber : MissionControl.Color.hull)
            .overlay(
                Rectangle()
                    .stroke(
                        highlighted ? MissionControl.Color.amber : MissionControl.Color.ruleHot,
                        lineWidth: MissionControl.Border.hairline
                    )
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.18), value: highlighted)
    }
}

#Preview {
    HStack(spacing: 12) {
        MCIconButton("⌁")
        MCIconButton("+")
        MCIconButton("⌘")
        MCIconButton("?", isActive: true)
    }
    .padding()
    .mcScreenBackground()
}
