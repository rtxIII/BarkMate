//
//  MCSettingRow.swift
//  DesignSystem
//
//  Settings 屏的标准行。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .s-row             L1266  grid 1fr + auto,gap 12,padding 12/0,底部 1pt rule
//    .s-row strong      L1274  Inter Tight 13pt 700 ink -0.02em
//    .s-row p           L1282  10.5pt inkSoft line-height 1.45
//    .s-row .val        L1288  10pt amber 700 0.08em
//    .s-row .val.dim    L1294  inkSoft
//    .s-row .val.on     L1295  lime 1pt 边 + uppercase
//

import SwiftUI

public struct MCSettingRow<Trailing: View>: View {
    private let title: String
    private let detail: String?
    private let trailing: Trailing

    public init(
        title: String,
        detail: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MissionControl.Font.interTight(size: 13, weight: .bold))
                    .tracking(-0.26)
                    .foregroundStyle(MissionControl.Color.ink)
                if let detail {
                    Text(detail)
                        .font(MissionControl.Font.jetBrainsMono(size: 10.5, weight: .regular))
                        .lineSpacing(4)
                        .foregroundStyle(MissionControl.Color.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .frame(alignment: .trailing)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MissionControl.Color.rule)
                .frame(height: MissionControl.Border.hairline)
        }
    }
}

/// `s-row .val` 样式的标量值文字(amber / dim 两态)。
public struct MCSettingValue: View {
    public enum Tone {
        case accent
        case dim
    }

    private let text: String
    private let tone: Tone

    public init(_ text: String, tone: Tone = .accent) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text.uppercased())
            .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(tone == .accent ? MissionControl.Color.amber : MissionControl.Color.inkSoft)
    }
}

/// `s-row .val.on` 样式的状态徽章(lime 描边 + uppercase)。
public struct MCSettingStateBadge: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = MissionControl.Color.lime) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text.uppercased())
            .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
            .tracking(1.3)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .overlay(
                Rectangle()
                    .stroke(color, lineWidth: MissionControl.Border.hairline)
            )
    }
}

#Preview {
    VStack(spacing: 0) {
        MCSettingRow(title: "Stale timeout", detail: "Running tasks become stale after 30 minutes.") {
            MCSettingValue("30m")
        }
        MCSettingRow(title: "On-device summary", detail: "Use Apple Intelligence when available.") {
            MCSettingStateBadge("On")
        }
        MCSettingRow(title: "Privacy", detail: "No analytics. Summary prompts never leave iPhone.") {
            MCSettingValue("local", tone: .dim)
        }
        MCSettingRow(title: "Manage servers", detail: "Add / remove / health check.") {
            MCSettingValue("open")
        }
    }
    .padding(.horizontal, 16)
    .mcScreenBackground()
}
