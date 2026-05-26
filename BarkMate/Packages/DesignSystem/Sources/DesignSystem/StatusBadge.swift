//
//  StatusBadge.swift
//  DesignSystem
//
//  AgentStatus 的胶囊徽章。compact = 卡片角标尺寸,非 compact = 详情页 hero 尺寸。
//

import SwiftUI
import Models

public struct StatusBadge: View {
    private let status: AgentStatus
    private let compact: Bool

    public init(status: AgentStatus, compact: Bool = true) {
        self.status = status
        self.compact = compact
    }

    public var body: some View {
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
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(AgentStatus.allCases, id: \.self) { status in
            HStack {
                StatusBadge(status: status, compact: true)
                StatusBadge(status: status, compact: false)
            }
        }
    }
    .padding()
}
