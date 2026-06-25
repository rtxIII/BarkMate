//
//  MCSetupHero.swift
//  DesignSystem
//
//  Setup 屏顶部 hero("Send one push. Get one living card.")。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .setup-hero        L754  padding 20/4/18,底部 1pt rule
//    .setup-hero .label L758  amber 底 + void 字 + uppercase tag
//    .setup-hero h4     L769  Inter Tight 34pt Black -0.045em
//    .setup-hero h4.serif L778 Instrument Serif italic + amber
//    .setup-hero p      L784  12pt inkSoft line-height 1.55
//

import SwiftUI

public struct MCSetupHero: View {
    private let tag: String
    private let title: String
    private let italicAccent: String?
    private let subtitle: String?

    public init(
        tag: String = "first push",
        title: String,
        italicAccent: String? = nil,
        subtitle: String? = nil
    ) {
        self.tag = tag
        self.title = title
        self.italicAccent = italicAccent
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tag.uppercased())
                .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(MissionControl.Color.void)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(MissionControl.Color.amber)
                .padding(.bottom, 14)

            titleText

            if let subtitle {
                Text(subtitle)
                    .font(MissionControl.Font.jetBrainsMono(size: 12, weight: .regular))
                    .lineSpacing(6)
                    .foregroundStyle(MissionControl.Color.inkSoft)
                    .padding(.top, 12)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MissionControl.Color.rule)
                .frame(height: MissionControl.Border.hairline)
        }
    }

    private var titleText: some View {
        let head = Text(title)
            .font(MissionControl.Font.interTight(size: 34, weight: .black))
            .tracking(-1.53)
            .foregroundStyle(MissionControl.Color.ink)

        if let italicAccent, !italicAccent.isEmpty {
            let accent = Text(italicAccent)
                .font(MissionControl.Font.italicAccent(size: 34))
                .foregroundStyle(MissionControl.Color.amber)
            return AnyView(head + accent)
        }
        return AnyView(head)
    }
}

#Preview {
    MCSetupHero(
        tag: "first push",
        title: "Send one push. Get one living ",
        italicAccent: "card.",
        subtitle: "带上 agent_status 和 task_id,同一个任务会原地更新,而不是堆成消息流。"
    )
    .padding(.horizontal, 16)
    .mcScreenBackground()
}
