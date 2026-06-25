//
//  MCChip.swift
//  DesignSystem
//
//  Mission Control filter chip。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .chip          L1082  padding 5/9,1pt ruleHot,hull 底,9pt 700 uppercase
//    .chip          L1090  inkSoft 字
//    .chip:hover    L1094  ink 字,inkSoft 边
//    .chip.active   L1095  ink 底 + void 字 + ink 边
//
//  状态由 caller 持有(isActive),组件只负责绘制。多选 / 单选由 caller 自行管理。
//

import SwiftUI

public struct MCChip: View {
    private let label: String
    private let isActive: Bool
    private let action: () -> Void

    public init(_ label: String, isActive: Bool, action: @escaping () -> Void) {
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label.uppercased())
        }
        .buttonStyle(MCChipStyle(isActive: isActive))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct MCChipStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let foreground: Color = {
            if isActive { return MissionControl.Color.void }
            return pressed ? MissionControl.Color.ink : MissionControl.Color.inkSoft
        }()
        let background: Color = isActive ? MissionControl.Color.ink : MissionControl.Color.hull
        let stroke: Color = {
            if isActive { return MissionControl.Color.ink }
            return pressed ? MissionControl.Color.inkSoft : MissionControl.Color.ruleHot
        }()
        return configuration.label
            .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background)
            .overlay(
                Rectangle()
                    .stroke(stroke, lineWidth: MissionControl.Border.hairline)
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.18), value: isActive)
    }
}

#Preview {
    struct Preview: View {
        @State private var selected = "all"

        var body: some View {
            HStack(spacing: 6) {
                ForEach(["all", "incoming", "outgoing", "memo"], id: \.self) { tag in
                    MCChip(tag, isActive: selected == tag) { selected = tag }
                }
            }
            .padding()
            .background(MissionControl.Color.void)
        }
    }
    return Preview()
}
