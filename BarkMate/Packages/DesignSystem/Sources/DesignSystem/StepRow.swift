//
//  StepRow.swift
//  DesignSystem
//
//  AgentDetailView 中单条 step 历史的展示。
//
//  - 旧 init(data:)             → 暖纸卡片风(月份左 42pt time + 卡片包裹)
//  - 新 init(data:, style: .missionControl)
//                               → 战术风(56pt time + 36pt ruleHot 短线 + 列式 + 底部 rule)
//
//  视觉契约参考 mock B `.step` L995–1034。
//

import SwiftUI

public struct StepRow: View {
    public enum Style {
        case missionControl
    }

    private enum Variant {
        case classic
        case missionControl
    }

    private let data: StepRowData
    private let variant: Variant

    public init(data: StepRowData) {
        self.data = data
        self.variant = .classic
    }

    public init(data: StepRowData, style: Style) {
        self.data = data
        switch style {
        case .missionControl: self.variant = .missionControl
        }
    }

    public var body: some View {
        switch variant {
        case .classic: classicBody
        case .missionControl: missionControlBody
        }
    }

    // MARK: - Classic

    private var classicBody: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(data.timeLabel)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(BarkTheme.Palette.ink.opacity(0.48))
                .frame(width: 42, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                StatusBadge(status: data.status, compact: true)
                Text(data.title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(BarkTheme.Palette.ink)
                Text(data.body)
                    .font(.system(size: 12, weight: .medium))
                    .lineSpacing(2)
                    .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            BarkTheme.Palette.paperHot.opacity(0.78),
            in: RoundedRectangle(cornerRadius: BarkTheme.Corner.mockCard, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BarkTheme.Corner.mockCard, style: .continuous)
                .stroke(BarkTheme.Palette.ink.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Mission Control

    private var missionControlBody: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(data.timeLabel)
                    .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(MissionControl.Color.amber)
                Rectangle()
                    .fill(MissionControl.Color.ruleHot)
                    .frame(width: 36, height: MissionControl.Border.hairline)
            }
            .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                StatusBadge(status: data.status, style: .missionControl)
                Text(data.title)
                    .font(MissionControl.Font.interTight(size: 13.5, weight: .bold))
                    .tracking(-0.27)
                    .foregroundStyle(MissionControl.Color.ink)
                Text(data.body)
                    .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                    .lineSpacing(4)
                    .foregroundStyle(MissionControl.Color.inkSoft)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MissionControl.Color.rule)
                .frame(height: MissionControl.Border.hairline)
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        StepRow(data: StepRowData(
            id: UUID(),
            timeLabel: "10:29",
            status: .running,
            title: "Fixing unit tests",
            body: "Typecheck found two mock signatures that need to be updated."
        ))
        StepRow(data: StepRowData(
            id: UUID(),
            timeLabel: "10:25",
            status: .running,
            title: "Updated auth.ts",
            body: "Extracted token validation into a smaller middleware function."
        ))
    }
    .padding()
    .background(MockScreenBackground())
}

#Preview("Mission Control") {
    VStack(spacing: 0) {
        StepRow(data: StepRowData(
            id: UUID(),
            timeLabel: "10:29",
            status: .waitingInput,
            title: "Waiting on env file",
            body: "Need DATABASE_URL for staging. Paste it back and I'll continue."
        ), style: .missionControl)

        StepRow(data: StepRowData(
            id: UUID(),
            timeLabel: "10:25",
            status: .running,
            title: "Updated auth.ts",
            body: "Extracted token validation into a smaller middleware function."
        ), style: .missionControl)

        StepRow(data: StepRowData(
            id: UUID(),
            timeLabel: "10:18",
            status: .done,
            title: "Tests pass",
            body: "All 312 unit tests green. Coverage at 84.2%."
        ), style: .missionControl)
    }
    .padding(.horizontal, 16)
    .mcScreenBackground()
}
