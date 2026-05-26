//
//  DetailHero.swift
//  DesignSystem
//
//  AgentDetailView 顶部深色 hero 卡:status badge + Iowan 36pt agent name +
//  monospace task_id + 3 个 DetailMetric(progress / eta / updated)。
//

import SwiftUI
import Models

public struct DetailHeroData: Equatable, Sendable {
    public let status: AgentStatus
    public let agentName: String
    public let taskID: String?
    public let progressLabel: String
    public let etaLabel: String
    public let updatedLabel: String

    public init(
        status: AgentStatus,
        agentName: String,
        taskID: String?,
        progressLabel: String,
        etaLabel: String,
        updatedLabel: String
    ) {
        self.status = status
        self.agentName = agentName
        self.taskID = taskID
        self.progressLabel = progressLabel
        self.etaLabel = etaLabel
        self.updatedLabel = updatedLabel
    }
}

public struct DetailHero: View {
    private let data: DetailHeroData

    public init(data: DetailHeroData) {
        self.data = data
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusBadge(status: data.status, compact: false)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.agentName)
                    .font(BarkTheme.Typography.heroSerif(size: 36))
                    .tracking(-2)
                    .foregroundStyle(.white)
                if let taskID = data.taskID {
                    Text(taskID)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            HStack(spacing: 9) {
                DetailMetric(value: data.progressLabel, label: "progress")
                DetailMetric(value: data.etaLabel, label: "eta")
                DetailMetric(value: data.updatedLabel, label: "updated")
            }
        }
        .padding(18)
        .heroBackground(decorationColor: data.status.color.opacity(0.45))
    }
}

private struct DetailMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.56))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.11), lineWidth: 1))
    }
}

#Preview {
    DetailHero(data: DetailHeroData(
        status: .running,
        agentName: "backend-refactor",
        taskID: "auth-migration-0420",
        progressLabel: "3/8",
        etaLabel: "12m",
        updatedLabel: "now"
    ))
    .padding()
    .background(MockScreenBackground())
}
