//
//  MCDossierHero.swift
//  DesignSystem
//
//  AgentDetailView 顶部 dossier hero(Mission Control 风)。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .d-hero            L883  padding 16,1pt amber,amber 渐变底
//    .d-hero::before    L889  左上 28×28 L 形,2pt amber
//    .d-hero::after     L899  右下 28×28 L 形,2pt amber
//    .d-hero .who       L909  Inter Tight 32pt Black,-0.04em
//    .d-hero .who.serif L918  Instrument Serif italic + amber
//    .d-hero .code-line L924  10pt inkSoft 0.04em
//    .d-metrics         L929  3 列 grid,gap 8,margin-top 14
//    .d-metric          L935  padding 8/10,void 底,1pt rule
//    .d-metric b        L940  Inter Tight 18pt 800
//    .d-metric span     L948  8.5pt 600 uppercase 0.14em
//
//  数据源沿用 DetailHeroData(Phase 3.2 已建)。
//

import SwiftUI

public struct MCDossierHero: View {
    private let data: DetailHeroData

    public init(data: DetailHeroData) {
        self.data = data
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StatusBadge(status: data.status, style: .missionControlLarge)
                .padding(.bottom, 6)

            agentNameText

            if let taskID = data.taskID {
                Text(taskID)
                    .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .regular))
                    .tracking(0.4)
                    .foregroundStyle(MissionControl.Color.inkSoft)
            }

            metricsRow
                .padding(.top, 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [MissionControl.Color.amber.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.amber, lineWidth: MissionControl.Border.hairline)
        )
        .overlay(alignment: .topLeading) {
            cornerL(rotation: 0)
        }
        .overlay(alignment: .bottomTrailing) {
            cornerL(rotation: 180)
        }
    }

    private var agentNameText: some View {
        let parts = data.agentName.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2 {
            let head = Text(String(parts[0]) + "-")
                .font(MissionControl.Font.interTight(size: 32, weight: .black))
                .tracking(-1.28)
                .foregroundStyle(MissionControl.Color.ink)
            let accent = Text(String(parts[1]))
                .font(MissionControl.Font.italicAccent(size: 32))
                .foregroundStyle(MissionControl.Color.amber)
            return AnyView(head + accent)
        }
        return AnyView(
            Text(data.agentName)
                .font(MissionControl.Font.interTight(size: 32, weight: .black))
                .tracking(-1.28)
                .foregroundStyle(MissionControl.Color.ink)
        )
    }

    private var metricsRow: some View {
        HStack(spacing: 8) {
            metricTile(value: data.progressLabel, label: "progress")
            metricTile(value: data.updatedLabel, label: "since update")
            metricTile(value: data.etaLabel, label: "eta")
        }
    }

    private func metricTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(MissionControl.Font.interTight(size: 18, weight: .heavy))
                .tracking(-0.54)
                .foregroundStyle(MissionControl.Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(MissionControl.Font.jetBrainsMono(size: 8.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MissionControl.Color.inkSoft)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MissionControl.Color.void)
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
        )
    }

    /// 28×28 的 L 形角标:画两条 2pt 边(top + left,或旋转 180° 成 bottom + right)。
    private func cornerL(rotation: Double) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 28))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 28, y: 0))
        }
        .stroke(MissionControl.Color.amber, lineWidth: MissionControl.Border.bracket)
        .frame(width: 28, height: 28)
        .rotationEffect(.degrees(rotation))
    }
}

#Preview {
    VStack(spacing: 16) {
        MCDossierHero(data: DetailHeroData(
            status: .waitingInput,
            agentName: "test-writer",
            taskID: "mock-coverage · TASK-0420",
            progressLabel: "04 / 07",
            etaLabel: "—",
            updatedLabel: "02m"
        ))

        MCDossierHero(data: DetailHeroData(
            status: .running,
            agentName: "backend-refactor",
            taskID: "auth-migration",
            progressLabel: "03 / 08",
            etaLabel: "12m",
            updatedLabel: "now"
        ))
    }
    .padding(16)
    .mcScreenBackground()
}
