//
//  MCProjectGroupCard.swift
//  DesignSystem
//
//  同一 project(agentID)下多个 session 卡的折叠聚合外壳。
//
//  Dashboard 三段(Needs you / Running / Settled)按 project 分组后:
//   - 单 session 组 → 调用方直接渲染原生卡(不经过本组件)。
//   - 多 session 组 → 本组件:头行(project 名 + 计数 + 聚合状态 + 展开指示)
//     + 折叠态摘要行 / 展开态逐 session 行。
//
//  导航保持在 App 层:session 行内容由调用方经 `row` builder 注入
//  (通常是 `NavigationLink { AgentDetailView } label: { MCSessionRow }`),
//  DesignSystem 不引用 App 的详情页。
//
//  视觉沿用 MCAttentionCard 语汇:左侧 4pt 状态 marker + glow,1pt 描边,深底。
//  marker/描边色取组内最紧急卡(排序后第一张)的 mcColor。
//

import SwiftUI
import Models

public struct MCProjectGroupCard<Row: View>: View {
    private let group: AgentProjectGroup
    @Binding private var isExpanded: Bool
    private let row: (AgentCardData) -> Row

    public init(
        group: AgentProjectGroup,
        isExpanded: Binding<Bool>,
        @ViewBuilder row: @escaping (AgentCardData) -> Row
    ) {
        self.group = group
        self._isExpanded = isExpanded
        self.row = row
    }

    private var leadStatus: AgentStatus {
        group.leadCard?.status ?? .running
    }

    public var body: some View {
        let markerColor = leadStatus.mcColor
        let markerGlow = leadStatus.mcGlow

        return VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.cards) { card in
                        row(card)
                    }
                }
                .padding(.top, 10)
            } else if let lead = group.leadCard {
                collapsedSummary(lead)
                    .padding(.top, 10)
            }
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

    // MARK: - Header

    private var header: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { isExpanded.toggle() }
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Text(group.projectName)
                    .font(MissionControl.Font.interTight(size: 17, weight: .heavy))
                    .tracking(-0.42)
                    .foregroundStyle(MissionControl.Color.ink)
                    .lineLimit(1)

                MCBracketBadge(code: "×\(group.cards.count)", color: MissionControl.Color.inkSoft)

                Spacer(minLength: 8)

                MCBracketBadge(status: leadStatus)

                Text(isExpanded ? "▾" : "▸")
                    .font(MissionControl.Font.jetBrainsMono(size: 12, weight: .bold))
                    .foregroundStyle(MissionControl.Color.amber)
                    .frame(width: 14)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("project-group-\(group.projectName)")
    }

    // MARK: - Collapsed summary

    private func collapsedSummary(_ lead: AgentCardData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text("»")
                    .font(MissionControl.Font.jetBrainsMono(size: 13, weight: .bold))
                    .foregroundStyle(MissionControl.Color.amber)
                Text(lead.latestStep)
                    .font(MissionControl.Font.jetBrainsMono(size: 12, weight: .regular))
                    .lineSpacing(4)
                    .foregroundStyle(MissionControl.Color.ink)
                    .lineLimit(2)
            }
            .padding(.leading, 4)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(MissionControl.Color.ruleHot)
                    .frame(width: 2)
            }
            .padding(.leading, 8)

            Text(summaryMeta)
                .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .regular))
                .tracking(0.4)
                .foregroundStyle(MissionControl.Color.inkSoft)
        }
    }

    /// `3 sessions · tap to expand`。计数用可读复数,提示可展开。
    private var summaryMeta: String {
        let n = group.cards.count
        let noun = n == 1 ? "session" : "sessions"
        return "\(n) \(noun) · tap to expand"
    }
}

/// project 组展开态的 session 行。与 `MCRunCompactRow` 的区别:
/// 组内所有行同属一个 project,不再显示 agentName initials(冗余),
/// 改以 session 短码 + 状态码定位单次 session。
public struct MCSessionRow: View {
    private let data: AgentCardData

    public init(data: AgentCardData) {
        self.data = data
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            MCBracketBadge(status: data.status)

            VStack(alignment: .leading, spacing: 2) {
                if let code = data.sessionCode {
                    Text(code)
                        .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(MissionControl.Color.inkSoft)
                        .lineLimit(1)
                }
                Text(data.latestStep)
                    .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                    .foregroundStyle(MissionControl.Color.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(data.progressLabel ?? data.updatedLabel)
                .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .regular))
                .tracking(0.4)
                .foregroundStyle(MissionControl.Color.inkSoft)
                .frame(minWidth: 36, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MissionControl.Color.rule)
                .frame(height: MissionControl.Border.hairline)
        }
    }
}

#Preview {
    struct Harness: View {
        @State private var expanded = true
        var body: some View {
            let cards = [
                AgentCardData(
                    id: UUID(), agentName: "claude:BarkAgent",
                    taskID: "7326f398-b555-428a-a0d4-9d29c44896c4",
                    status: .waitingInput, latestStep: "Claude needs your permission",
                    progressLabel: "2/5", progressFraction: 0.4, etaLabel: nil,
                    updatedLabel: "2m", isPinned: false, isMuted: false
                ),
                AgentCardData(
                    id: UUID(), agentName: "claude:BarkAgent",
                    taskID: "00e5b8c8-1468-4e50-845a-9442faeef8c3",
                    status: .waitingInput, latestStep: "Confirm overwrite existing mocks",
                    progressLabel: nil, progressFraction: nil, etaLabel: nil,
                    updatedLabel: "now", isPinned: false, isMuted: false
                ),
                AgentCardData(
                    id: UUID(), agentName: "claude:BarkAgent",
                    taskID: "a0d49d29-1111-2222-3333-444455556666",
                    status: .running, latestStep: "Running integration tests",
                    progressLabel: "58%", progressFraction: 0.58, etaLabel: nil,
                    updatedLabel: "1m", isPinned: false, isMuted: false
                )
            ]
            let group = AgentProjectGroup(projectName: "claude:BarkAgent", cards: cards)
            return VStack(spacing: 10) {
                MCProjectGroupCard(group: group, isExpanded: $expanded) { card in
                    MCSessionRow(data: card)
                }
            }
            .padding(.horizontal, 16)
            .mcScreenBackground()
        }
    }
    return Harness()
}
