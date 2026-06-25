//
//  MCSectionHeader.swift
//  DesignSystem
//
//  Mission Control 列表分组的小标题行(如 "▸ NEEDS YOU  /  02 cards")。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .sec-hd          L587  flex space-between,margin 18/0/8,10pt uppercase tracking 0.18em
//    .sec-hd .lhs     L597  ink 文字
//    .sec-hd .lhs::before L598  amber "▸ "
//    .sec-hd .rhs     L602  inkSoft 文字
//

import SwiftUI

public struct MCSectionHeader: View {
    private let title: String
    private let trailing: String?

    public init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 0) {
                Text("▸ ")
                    .foregroundStyle(MissionControl.Color.amber)
                Text(title.uppercased())
                    .foregroundStyle(MissionControl.Color.ink)
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing.uppercased())
                    .foregroundStyle(MissionControl.Color.inkSoft)
            }
        }
        .font(MissionControl.Font.captionMono)
        .tracking(1.8)
        .padding(.top, MissionControl.Spacing.sectionGap)
        .padding(.bottom, MissionControl.Spacing.sectionAfterHeader)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        MCSectionHeader("Needs you", trailing: "02 cards")
        MCSectionHeader("Running", trailing: "03 agents")
        MCSectionHeader("Settled", trailing: "01")
        MCSectionHeader("Privacy")
    }
    .padding(.horizontal, 16)
    .mcScreenBackground()
}
