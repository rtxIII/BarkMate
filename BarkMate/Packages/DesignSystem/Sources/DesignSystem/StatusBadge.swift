//
//  StatusBadge.swift
//  DesignSystem
//
//  AgentStatus 的胶囊徽章。compact = 卡片角标尺寸,非 compact = 详情页 hero 尺寸。
//
//  Mission Control 变体:`StatusBadge(status:, style: .missionControl)`
//   - 方角矩形 + 1pt mcColor 描边 + mcGlow 底色 + bodyMono `[ WAIT ]` 文字
//   - 旧 init(status:, compact:) 行为完全不变,旧调用方零影响
//

import SwiftUI
import Models

public struct StatusBadge: View {
    public enum Style {
        /// 紧凑 MC 风(行内 chip)。
        case missionControl
        /// 详情页大号 MC 风(更大字 + 更宽 padding)。
        case missionControlLarge
    }

    private enum Variant {
        case classicCompact
        case classicLarge
        case missionControl
        case missionControlLarge
    }

    private let status: AgentStatus
    private let variant: Variant

    public init(status: AgentStatus, compact: Bool = true) {
        self.status = status
        self.variant = compact ? .classicCompact : .classicLarge
    }

    public init(status: AgentStatus, style: Style) {
        self.status = status
        switch style {
        case .missionControl: self.variant = .missionControl
        case .missionControlLarge: self.variant = .missionControlLarge
        }
    }

    public var body: some View {
        switch variant {
        case .classicCompact, .classicLarge:
            classicBody(compact: variant == .classicCompact)
        case .missionControl, .missionControlLarge:
            missionControlBody(large: variant == .missionControlLarge)
        }
    }

    // MARK: - Classic (legacy 暖纸)

    private func classicBody(compact: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(status.label)
        }
        .font(.system(size: compact ? 8 : 10, weight: .heavy))
        .tracking(0.5)
        .textCase(.uppercase)
        .foregroundStyle(status.color)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 5 : 7)
        .background(status.color.opacity(0.13), in: Capsule())
        .overlay(Capsule().stroke(status.color.opacity(0.28), lineWidth: 1))
    }

    // MARK: - Mission Control

    private func missionControlBody(large: Bool) -> some View {
        let color = status.mcColor
        let glow = status.mcGlow
        return Text(status.mcCode)
            .font(large
                  ? MissionControl.Font.jetBrainsMono(size: 13, weight: .bold)
                  : MissionControl.Font.bodyMono)
            .tracking(1.0)
            .foregroundStyle(color)
            .padding(.horizontal, large ? 10 : 7)
            .padding(.vertical, large ? 6 : 4)
            .background(glow)
            .overlay(
                Rectangle()
                    .stroke(color, lineWidth: MissionControl.Border.hairline)
            )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(AgentStatus.allCases, id: \.self) { status in
            HStack(spacing: 10) {
                StatusBadge(status: status, compact: true)
                StatusBadge(status: status, compact: false)
                StatusBadge(status: status, style: .missionControl)
                StatusBadge(status: status, style: .missionControlLarge)
            }
        }
    }
    .padding()
}
