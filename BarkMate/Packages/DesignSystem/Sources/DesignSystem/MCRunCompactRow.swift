//
//  MCRunCompactRow.swift
//  DesignSystem
//
//  Dashboard "Running" / "Settled" 紧凑行。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .r-row             L696  grid 28pt + 1fr + 90pt + auto,gap 10
//    .r-row             L700  padding 10/0,底部 1pt rule
//    .r-row .av         L709  2 字母 initials,JBMono 10pt cyan(done 切 lime)
//    .r-row .body       L715  Inter Tight 13pt 700 ink + 9.5pt inkSoft 副文
//    .r-row .bar        L729  4pt MCProgressBar
//    .r-row .pct        L742  11pt cyan/lime 700
//
//  数据源沿用 AgentCardData(plan 提"需要新 VM RunCompactRowData",但 AgentCardData
//  已包含所有需要字段——initials 在视图层 derive,跳过新 DTO)。
//

import SwiftUI
import Models

public struct MCRunCompactRow: View {
    private let data: AgentCardData

    public init(data: AgentCardData) {
        self.data = data
    }

    public var body: some View {
        let isDone = data.status == .done
        let accent: Color = isDone ? MissionControl.Color.lime : data.status.mcColor
        let glow: Color = isDone ? MissionControl.Color.limeGlow : data.status.mcGlow
        // done 强制满条(手动 Mark Done 或未带 progress 的完成推送都会命中);
        // 非 done 且无 progress 数据时 effectiveFraction 为 nil → 不画进度条/百分比列,
        // 而非用 0 渲染成"卡在 0%"的空条。
        let effectiveFraction: Double? = isDone ? 1 : data.progressFraction

        return HStack(alignment: .center, spacing: 10) {
            Text(initials)
                .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(accent)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(data.agentName)
                    .font(MissionControl.Font.interTight(size: 13, weight: .bold))
                    .tracking(-0.26)
                    .foregroundStyle(MissionControl.Color.ink)
                    .lineLimit(1)
                Text(subBody)
                    .font(MissionControl.Font.jetBrainsMono(size: 9.5, weight: .regular))
                    .foregroundStyle(MissionControl.Color.inkSoft)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let fraction = effectiveFraction {
                MCProgressBar(value: fraction, color: accent, glow: glow)
                    .frame(width: 90)

                Text(pctLabel(fraction))
                    .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(accent)
                    .frame(minWidth: 36, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MissionControl.Color.rule)
                .frame(height: MissionControl.Border.hairline)
        }
    }

    private var initials: String {
        let parts = data.agentName
            .split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == " " })
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
        return parts.isEmpty ? "?" : parts
    }

    private var subBody: String {
        if let taskID = data.taskID {
            return "\(taskID) · \(data.latestStep)"
        }
        return data.latestStep
    }

    /// fraction 已由 body 保证非 nil(done→1,其余为已解析值)。done 显 "DONE",否则显百分比。
    private func pctLabel(_ fraction: Double) -> String {
        if data.status == .done { return "DONE" }
        return "\(Int(fraction * 100))%"
    }
}

#Preview {
    VStack(spacing: 0) {
        MCRunCompactRow(data: AgentCardData(
            id: UUID(),
            agentName: "backend-refactor",
            taskID: "auth-migration",
            status: .running,
            latestStep: "refactoring middleware",
            progressLabel: "38%",
            progressFraction: 0.38,
            etaLabel: nil,
            updatedLabel: "now",
            isPinned: false,
            isMuted: false
        ))
        MCRunCompactRow(data: AgentCardData(
            id: UUID(),
            agentName: "dependency-updater",
            taskID: "weekly-bump",
            status: .running,
            latestStep: "installing packages",
            progressLabel: "25%",
            progressFraction: 0.25,
            etaLabel: nil,
            updatedLabel: "now",
            isPinned: false,
            isMuted: false
        ))
        MCRunCompactRow(data: AgentCardData(
            id: UUID(),
            agentName: "e2e-runner",
            taskID: "checkout-flow",
            status: .done,
            latestStep: "06/06 passed",
            progressLabel: nil,
            progressFraction: 1.0,
            etaLabel: nil,
            updatedLabel: "5m ago",
            isPinned: false,
            isMuted: false
        ))
    }
    .padding(.horizontal, 16)
    .mcScreenBackground()
}
