//
//  AgentTaskCard.swift
//  DesignSystem
//
//  Dashboard active grid 单元卡。Mock 契约见 AgentMockPrototypeView.AgentTaskCard:
//    - paperHot 圆角 24 卡 + 左侧状态色条 5pt + 右上 status 色装饰圆
//    - avatar(首字母)+ Iowan 14pt heavy agent name + monospace 9pt task_id
//    - latestStep 2 行 + ProgressView + (progressLabel · updatedLabel)
//

import SwiftUI
import Models

public struct AgentTaskCard: View {
    private let data: AgentCardData

    public init(data: AgentCardData) {
        self.data = data
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                AgentAvatar(agentName: data.agentName)
                Spacer()
                StatusBadge(status: data.status, compact: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(data.agentName)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(BarkTheme.Palette.ink)
                    .lineLimit(1)
                if let taskID = data.taskID {
                    Text(taskID)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(BarkTheme.Palette.ink.opacity(0.48))
                        .lineLimit(1)
                }
            }

            Text(data.latestStep)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BarkTheme.Palette.ink.opacity(0.72))
                .lineLimit(2)
                .frame(minHeight: 34, alignment: .topLeading)

            ProgressView(value: data.progressFraction ?? 0)
                .tint(data.status.color)
                .background(BarkTheme.Palette.ink.opacity(0.08), in: Capsule())

            HStack {
                Text(footerText)
                Spacer()
                if data.isMuted { Image(systemName: "bell.slash.fill") }
                if data.isPinned { Image(systemName: "pin.fill") }
            }
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(BarkTheme.Palette.ink.opacity(0.45))
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: BarkTheme.Corner.largeCard, style: .continuous)
                .fill(BarkTheme.Palette.paperHot.opacity(0.82))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(data.status.color)
                        .frame(width: 5)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(data.status.color.opacity(0.18))
                        .frame(width: 112, height: 112)
                        .offset(x: 48, y: -50)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: BarkTheme.Corner.largeCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BarkTheme.Corner.largeCard, style: .continuous)
                .stroke(BarkTheme.Palette.ink.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: BarkTheme.Palette.ink.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    private var footerText: String {
        if let progress = data.progressLabel {
            return "\(progress) · \(data.updatedLabel)"
        }
        return data.updatedLabel
    }
}

#Preview {
    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
        AgentTaskCard(data: AgentCardData(
            id: UUID(),
            agentName: "backend-refactor",
            taskID: "auth-migration-0420",
            status: .running,
            latestStep: "Refactoring auth middleware",
            progressLabel: "3/8",
            progressFraction: 3.0 / 8,
            etaLabel: "12m",
            updatedLabel: "now",
            isPinned: true,
            isMuted: false
        ))
        AgentTaskCard(data: AgentCardData(
            id: UUID(),
            agentName: "test-writer",
            taskID: "mock-coverage",
            status: .waitingInput,
            latestStep: "Confirm overwrite existing mocks",
            progressLabel: "4/7",
            progressFraction: 4.0 / 7,
            etaLabel: "waiting",
            updatedLabel: "2m",
            isPinned: false,
            isMuted: false
        ))
    }
    .padding()
    .background(MockScreenBackground())
}
