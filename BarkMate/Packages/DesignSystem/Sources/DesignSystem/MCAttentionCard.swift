//
//  MCAttentionCard.swift
//  DesignSystem
//
//  "Needs you" 大卡(Dashboard 顶部 triage 下方主要内容)。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .a-card           L605  amber 1pt 描边 + amber/transparent 渐变底
//    .a-card::before   L614  4pt amber 左 marker + amber-glow shadow
//    .a-card.stuck     L624  blocked 态切 orange
//    .top              L628  flex space-between,顶部 agent + status badge
//    .who              L634  Inter Tight 17pt 800 + Instrument Serif italic 强调
//    .code-line        L648  9.5pt inkSoft 0.04em tracking
//    .ask              L655  12pt ink + 12pt 左 padding + 2pt ruleHot 左边 + »amber 前缀
//    .meta             L668  10pt inkSoft 0.04em
//

import SwiftUI
import Models

public struct MCAttentionCard: View {
    private let data: AgentCardData

    public init(data: AgentCardData) {
        self.data = data
    }

    public var body: some View {
        // mock B 的 .a-card.stuck 视觉(橙色描边/marker)同时覆盖 blocked 与 failed,
        // 表达"有问题需要看一眼"。waitingInput 用 amber(默认色带)。
        let usesStuckTone = data.status == .blocked || data.status == .failed
        let markerColor: Color = usesStuckTone
            ? MissionControl.Color.orange
            : MissionControl.Color.amber
        let markerGlow: Color = usesStuckTone
            ? MissionControl.Color.orangeGlow
            : MissionControl.Color.amberGlow

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    agentNameText
                    if let codeLine = mcCodeLine {
                        Text(codeLine)
                            .font(MissionControl.Font.jetBrainsMono(size: 9.5, weight: .regular))
                            .tracking(0.4)
                            .foregroundStyle(MissionControl.Color.inkSoft)
                    }
                }
                Spacer(minLength: 8)
                MCBracketBadge(status: data.status)
            }

            askBlock
                .padding(.top, 12)
                .padding(.bottom, 12)

            HStack {
                Text(data.updatedLabel)
                Spacer()
                if let progress = data.progressLabel {
                    Text(progress)
                }
            }
            .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .regular))
            .tracking(0.4)
            .foregroundStyle(MissionControl.Color.inkSoft)
        }
        .padding(.vertical, 14)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .background(
            LinearGradient(
                colors: [markerColor.opacity(0.06), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(markerColor)
                .frame(width: MissionControl.Border.statusMarker)
                .shadow(color: markerGlow, radius: 12, x: 0, y: 0)
        }
        .overlay(
            Rectangle()
                .stroke(markerColor, lineWidth: MissionControl.Border.hairline)
        )
    }

    private var agentNameText: some View {
        let parts = data.agentName.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2 {
            let head = Text(String(parts[0]) + "-")
                .font(MissionControl.Font.interTight(size: 17, weight: .heavy))
                .tracking(-0.42)
                .foregroundStyle(MissionControl.Color.ink)
            let accent = Text(String(parts[1]))
                .font(MissionControl.Font.italicAccent(size: 17))
                .foregroundStyle(MissionControl.Color.amber)
            return AnyView(head + accent)
        }
        return AnyView(
            Text(data.agentName)
                .font(MissionControl.Font.interTight(size: 17, weight: .heavy))
                .tracking(-0.42)
                .foregroundStyle(MissionControl.Color.ink)
        )
    }

    private var askBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("»")
                .font(MissionControl.Font.jetBrainsMono(size: 13, weight: .bold))
                .foregroundStyle(MissionControl.Color.amber)
            Text(data.latestStep)
                .font(MissionControl.Font.jetBrainsMono(size: 12, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(MissionControl.Color.ink)
        }
        .padding(.leading, 4)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(MissionControl.Color.ruleHot)
                .frame(width: 2)
        }
        .padding(.leading, 8)
    }

    private var mcCodeLine: String? {
        var segments: [String] = []
        if let taskID = data.taskID { segments.append(taskID) }
        if let progress = data.progressLabel { segments.append(progress) }
        return segments.isEmpty ? nil : segments.joined(separator: " · ")
    }
}

#Preview {
    VStack(spacing: 10) {
        MCAttentionCard(data: AgentCardData(
            id: UUID(),
            agentName: "test-writer",
            taskID: "TASK-0420",
            status: .waitingInput,
            latestStep: "Confirm overwrite existing mocks? The agent wants to replace test doubles in __mocks__.",
            progressLabel: "04 / 07",
            progressFraction: 4.0 / 7,
            etaLabel: "waiting",
            updatedLabel: "updated 2m ago",
            isPinned: false,
            isMuted: false
        ))

        MCAttentionCard(data: AgentCardData(
            id: UUID(),
            agentName: "log-analyzer",
            taskID: "TASK-0418",
            status: .blocked,
            latestStep: "Missing Grafana token — cannot read panels. Add a token in Settings or skip this run.",
            progressLabel: "02 / 05",
            progressFraction: 2.0 / 5,
            etaLabel: nil,
            updatedLabel: "blocked 7m ago",
            isPinned: false,
            isMuted: false
        ))
    }
    .padding(.horizontal, 16)
    .mcScreenBackground()
}
