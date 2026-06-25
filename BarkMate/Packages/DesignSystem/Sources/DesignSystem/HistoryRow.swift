//
//  HistoryRow.swift
//  DesignSystem
//
//  History tab 全量行 + Dashboard 底部 mini 行。两个尺寸共用 HistoryItemData。
//
//  - 旧 init(data:)             → 暖纸卡片风(mockCardPadding 包裹)
//  - 新 init(data:, style: .missionControl)
//                               → 战术风(1fr 标题 + 右 amber time + 8pt kind metadata + 底部 rule)
//
//  视觉契约参考 mock B `.h-item` L1101–1137。
//

import SwiftUI

public struct HistoryRow: View {
    public enum Style {
        case missionControl
    }

    private enum Variant {
        case classic
        case missionControl
    }

    private let data: HistoryItemData
    private let variant: Variant

    public init(data: HistoryItemData) {
        self.data = data
        self.variant = .classic
    }

    public init(data: HistoryItemData, style: Style) {
        self.data = data
        switch style {
        case .missionControl: self.variant = .missionControl
        }
    }

    public var body: some View {
        switch variant {
        case .classic: classicBody
        case .missionControl: HistoryItemMissionControlRow(data: data)
        }
    }

    private var classicBody: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(data.title)
                    .font(.headline.weight(.heavy))
                Text(data.body)
                    .font(.subheadline)
                    .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
            }
            Spacer()
            Pill(data.kindBadge)
        }
        .mockCardPadding()
    }
}

public struct HistoryMiniRow: View {
    public enum Style {
        case missionControl
    }

    private enum Variant {
        case classic
        case missionControl
    }

    private let data: HistoryItemData
    private let variant: Variant

    public init(data: HistoryItemData) {
        self.data = data
        self.variant = .classic
    }

    public init(data: HistoryItemData, style: Style) {
        self.data = data
        switch style {
        case .missionControl: self.variant = .missionControl
        }
    }

    public var body: some View {
        switch variant {
        case .classic: classicBody
        case .missionControl: HistoryItemMissionControlRow(data: data)
        }
    }

    private var classicBody: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(data.title)
                    .font(.system(size: 13, weight: .heavy))
                Text(data.body)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
                    .lineLimit(2)
            }
            Spacer()
            Pill(data.kindBadge)
        }
        .mockCardPadding()
    }
}

// MARK: - Mission Control variant (shared body)

/// HistoryRow / HistoryMiniRow 的 Mission Control 渲染体共享实现。
/// 走 mock B `.h-item` 布局:左 1fr 标题 + 右 amber time / 8pt kind metadata,底部 1pt rule。
private struct HistoryItemMissionControlRow: View {
    let data: HistoryItemData

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // mock B `.h-item` 标题前置一个 bracket badge 前缀
                // ([ AGT-DONE ] / [ BARK ] / [ STALE ])。
                MCBracketBadge(
                    code: "[ \(data.kindBadge.uppercased()) ]",
                    color: badgeColor
                )
                Text(data.title)
                    .font(MissionControl.Font.interTight(size: 13.5, weight: .bold))
                    .tracking(-0.27)
                    .foregroundStyle(MissionControl.Color.ink)
                    .padding(.top, 2)
                Text(data.body)
                    .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(MissionControl.Color.inkSoft)
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(Self.timeString(for: data.updatedAt))
                    .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(MissionControl.Color.amber)
                Text(data.kindBadge.uppercased())
                    .font(MissionControl.Font.jetBrainsMono(size: 8, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(MissionControl.Color.inkSoft)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MissionControl.Color.rule)
                .frame(height: MissionControl.Border.hairline)
        }
    }

    private var badgeColor: Color {
        switch data.kind {
        case .agent: return MissionControl.Color.lime
        case .incoming: return MissionControl.Color.cyan
        case .stale: return MissionControl.Color.inkMute
        }
    }

    /// 今天显示 HH:mm,其它日期显示 MMM dd(英文短月)。
    private static func timeString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        }
        return date.formatted(.dateTime.month(.abbreviated).day(.twoDigits))
    }
}

#Preview {
    VStack(spacing: 10) {
        HistoryRow(data: HistoryItemData(
            id: UUID(),
            kind: .incoming,
            kindBadge: "incoming",
            title: "Build finished",
            body: "旧 Bark 推送:main branch build completed in 12m32s.",
            updatedAt: .now
        ))
        HistoryMiniRow(data: HistoryItemData(
            id: UUID(),
            kind: .incoming,
            kindBadge: "BARK",
            title: "Deploy preview link",
            body: "Legacy push · no agent_status · staging url posted by hook.",
            updatedAt: .now
        ))
    }
    .padding()
    .background(MockScreenBackground())
}

#Preview("Mission Control") {
    VStack(spacing: 0) {
        HistoryRow(data: HistoryItemData(
            id: UUID(),
            kind: .incoming,
            kindBadge: "incoming",
            title: "Build finished",
            body: "main branch build completed in 12m32s.",
            updatedAt: .now
        ), style: .missionControl)

        HistoryMiniRow(data: HistoryItemData(
            id: UUID(),
            kind: .incoming,
            kindBadge: "BARK",
            title: "Deploy preview link",
            body: "Legacy push · no agent_status · staging url posted by hook.",
            updatedAt: Date(timeIntervalSinceNow: -86400 * 2)
        ), style: .missionControl)

        HistoryRow(data: HistoryItemData(
            id: UUID(),
            kind: .agent,
            kindBadge: "agent",
            title: "Sent to test-writer",
            body: "Confirmed env var. Resume execution.",
            updatedAt: Date(timeIntervalSinceNow: -86400 * 10)
        ), style: .missionControl)
    }
    .padding(.horizontal, 16)
    .mcScreenBackground()
}
