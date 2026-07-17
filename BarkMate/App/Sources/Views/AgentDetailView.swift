//
//  AgentDetailView.swift
//  BarkAgent
//
//  V0.4 Day 6 — Mission Control 重写。
//  MCConsoleHeader + MCDossierHero + SummaryPanel(MC) + 4 列 MC 按钮 + StepRow(MC)。
//  数据流(@Query / SwiftData actions / SummaryPanelState)保持不变。
//

import SwiftUI
import SwiftData
import Models
import DesignSystem

struct AgentDetailView: View {

    let taskID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var tasks: [AgentTask]

    // AI 摘要为 V1.1 功能(Apple Intelligence FoundationModels),V1.0 发布构建隐藏入口。
    // 代码保留;把 BARKAGENT_AI_SUMMARY 加进 build settings 即可复活。
    #if BARKAGENT_AI_SUMMARY
    @State private var summaryState: SummaryPanelState = .ready
    #endif

    init(taskID: UUID) {
        self.taskID = taskID
        _tasks = Query(filter: #Predicate<AgentTask> { $0.id == taskID })
    }

    private var task: AgentTask? { tasks.first }

    var body: some View {
        Group {
            if let task {
                content(for: task)
            } else {
                ContentUnavailableView(
                    "Agent not found",
                    systemImage: "questionmark.folder",
                    description: Text("This task may have been archived or deleted.")
                )
            }
        }
        .mcScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func content(for task: AgentTask) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MCConsoleHeader(
                    crumbs: ["OPS", "DOSSIER", task.taskID ?? task.id.uuidString.prefix(8).uppercased()],
                    title: "Dossier"
                ) {
                    HStack(spacing: 8) {
                        ShareLink(item: AgentShareSnippet.text(from: heroData(task))) {
                            Text("⇪")
                                .font(MissionControl.Font.jetBrainsMono(size: 13, weight: .bold))
                                .foregroundStyle(MissionControl.Color.ink)
                                .frame(width: 32, height: 32)
                                .background(MissionControl.Color.hull)
                                .overlay(
                                    Rectangle()
                                        .stroke(MissionControl.Color.ruleHot,
                                                lineWidth: MissionControl.Border.hairline)
                                )
                        }
                        MCIconButton("←") { dismiss() }
                    }
                }
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 14) {
                    MCDossierHero(data: heroData(task))

                    #if BARKAGENT_AI_SUMMARY
                    SummaryPanel(
                        state: summaryState,
                        onSummarize: { startSummary(task) },
                        style: .missionControl
                    )
                    #endif

                    actionRow(task)

                    let steps = sortedSteps(task)
                    MCSectionHeader("Step log", trailing: pushesLabel(steps.count))

                    VStack(spacing: 0) {
                        ForEach(steps) { step in
                            StepRow(data: stepData(step), style: .missionControl)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func actionRow(_ task: AgentTask) -> some View {
        HStack(spacing: 8) {
            Button(task.isPinned ? "Unpin" : "Pin") { togglePin(task) }
                .buttonStyle(MCGhostButtonStyle())
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("agent-detail-pin")
            Button(task.isMuted ? "Unmute" : "Mute") { toggleMute(task) }
                .buttonStyle(MCGhostButtonStyle())
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("agent-detail-mute")
            Button("Archive") { archive(task) }
                .buttonStyle(MCGhostButtonStyle())
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("agent-detail-archive")
            Button("Done") { markDone(task) }
                .buttonStyle(MCPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("agent-detail-done")
        }
    }

    private func pushesLabel(_ n: Int) -> String {
        n < 10 ? "0\(n) pushes" : "\(n) pushes"
    }

    // MARK: - View-model

    private func heroData(_ task: AgentTask) -> DetailHeroData {
        DetailHeroData(
            status: task.status,
            agentName: task.displayName,
            taskID: codeLine(for: task),
            progressLabel: task.progress ?? "—",
            etaLabel: AgentCardData.etaLabel(from: task.eta) ?? "—",
            updatedLabel: AgentCardData.relativeLabel(from: task.updatedAt)
        )
    }

    private func codeLine(for task: AgentTask) -> String? {
        var segments: [String] = []
        if let taskID = task.taskID { segments.append(taskID) }
        return segments.isEmpty ? nil : segments.joined(separator: " · ")
    }

    private func sortedSteps(_ task: AgentTask) -> [AgentStep] {
        task.steps.sorted { $0.createdAt > $1.createdAt }
    }

    private func stepData(_ step: AgentStep) -> StepRowData {
        StepRowData(
            id: step.id,
            timeLabel: Self.timeFormatter.string(from: step.createdAt),
            status: step.status,
            title: step.title ?? "Step",
            body: step.body
        )
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    // MARK: - Actions

    private func togglePin(_ task: AgentTask) {
        task.isPinned.toggle()
        task.updatedAt = .now
        try? modelContext.save()
    }

    private func toggleMute(_ task: AgentTask) {
        task.isMuted.toggle()
        task.updatedAt = .now
        try? modelContext.save()
    }

    private func archive(_ task: AgentTask) {
        task.isArchived = true
        task.updatedAt = .now
        try? modelContext.save()
    }

    private func markDone(_ task: AgentTask) {
        task.status = .done
        task.updatedAt = .now
        try? modelContext.save()
    }

    #if BARKAGENT_AI_SUMMARY
    private func startSummary(_ task: AgentTask) {
        // Phase 6 实际接 FoundationModels。此处仅做三态切换占位。
        withAnimation(.easeInOut(duration: 0.2)) { summaryState = .loading }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.2)) {
                summaryState = .generated(
                    text: task.lastSummary ?? "本地摘要将在 Phase 6 接入 Apple Intelligence 后填充。",
                    cacheLabel: task.lastSummaryAt.map { "cached · \(AgentCardData.relativeLabel(from: $0))" }
                )
            }
        }
    }
    #endif
}
