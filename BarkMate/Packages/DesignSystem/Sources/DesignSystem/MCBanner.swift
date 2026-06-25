//
//  MCBanner.swift
//  DesignSystem
//
//  Setup / 屏顶状态横幅(Mission Control 风)。替换原 NotificationStatusBanner 用于 MC 屏。
//
//  布局:
//    - 1pt 着色边 + 4pt 左 marker + 着色 glow
//    - 顶部 [ KIND ] tag + 标题
//    - 副 detail
//    - 可选 action button(右侧)
//
//  Tone(色板映射):
//    .warning  → amber
//    .danger   → magenta
//    .alert    → orange
//    .info     → cyan
//

import SwiftUI

public struct MCBanner: View {
    public enum Tone {
        case warning, danger, alert, info

        var color: Color {
            switch self {
            case .warning: return MissionControl.Color.amber
            case .danger: return MissionControl.Color.magenta
            case .alert: return MissionControl.Color.orange
            case .info: return MissionControl.Color.cyan
            }
        }

        var glow: Color {
            switch self {
            case .warning: return MissionControl.Color.amberGlow
            case .danger: return MissionControl.Color.magentaGlow
            case .alert: return MissionControl.Color.orangeGlow
            case .info: return MissionControl.Color.cyanGlow
            }
        }

        var tag: String {
            switch self {
            case .warning: return "[ WARN ]"
            case .danger: return "[ FAIL ]"
            case .alert: return "[ ALERT ]"
            case .info: return "[ INFO ]"
            }
        }
    }

    private let tone: Tone
    private let title: String
    private let detail: String?
    private let actionLabel: String?
    private let action: (() -> Void)?

    public init(
        tone: Tone,
        title: String,
        detail: String? = nil,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.tone = tone
        self.title = title
        self.detail = detail
        self.actionLabel = actionLabel
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(tone.tag)
                    .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(tone.color)
                Text(title)
                    .font(MissionControl.Font.interTight(size: 15, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(MissionControl.Color.ink)
                if let detail {
                    Text(detail)
                        .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                        .lineSpacing(4)
                        .foregroundStyle(MissionControl.Color.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionLabel, let action {
                Button(actionLabel.uppercased(), action: action)
                    .buttonStyle(MCBannerActionStyle(tone: tone))
            }
        }
        .padding(.vertical, 14)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .background(
            LinearGradient(
                colors: [tone.color.opacity(0.06), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tone.color)
                .frame(width: MissionControl.Border.statusMarker)
                .shadow(color: tone.glow, radius: 12, x: 0, y: 0)
        }
        .overlay(
            Rectangle()
                .stroke(tone.color, lineWidth: MissionControl.Border.hairline)
        )
    }
}

private struct MCBannerActionStyle: ButtonStyle {
    let tone: MCBanner.Tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
            .tracking(1.3)
            .foregroundStyle(configuration.isPressed ? MissionControl.Color.void : tone.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? tone.color : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(tone.color, lineWidth: MissionControl.Border.hairline)
            )
    }
}

#Preview {
    VStack(spacing: 10) {
        MCBanner(
            tone: .warning,
            title: "Notifications are off",
            detail: "Open iOS Settings → BarkAgent to allow notifications.",
            actionLabel: "Open"
        ) { }

        MCBanner(
            tone: .danger,
            title: "Storage unavailable",
            detail: "BarkAgent could not open its shared storage.",
            actionLabel: "Help"
        ) { }

        MCBanner(
            tone: .info,
            title: "Tip",
            detail: "Send agent_status to keep pushes from stacking up.",
            actionLabel: nil
        )
    }
    .padding(16)
    .mcScreenBackground()
}
