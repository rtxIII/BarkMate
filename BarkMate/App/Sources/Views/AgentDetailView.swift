//
//  AgentDetailView.swift
//  BarkMate
//
//  V0.3 Phase 3.2 Agent detail。
//  DetailHero(深色) + Pin/Mute/Archive/Mark done 按钮行 + SummaryPanel 占位(Phase 6 接 LLM)
//  + 重写 StepRow 卡片列表。
//

import SwiftUI
import SwiftData
import Models
import DesignSystem

struct AgentDetailView: View {

    let taskID: UUID

    @Environment(\.modelContext) private var modelContext

    @Query private var tasks: [AgentTask]

    @State private var summaryState: SummaryPanelState = .ready

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
        .background(MockScreenBackground())
        .navigationTitle("Agent detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(for task: AgentTask) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                DetailHero(data: heroData(task))

                actionRow(task)

                SummaryPanel(state: summaryState, onSummarize: { startSummary(task) })

                let steps = sortedSteps(task)
                SectionTitle("Step History", trailing: "\(steps.count) pushes")

                VStack(spacing: 10) {
                    ForEach(steps) { step in
                        StepRow(data: stepData(step))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func actionRow(_ task: AgentTask) -> some View {
        HStack(spacing: 9) {
            Button(task.isPinned ? "Unpin" : "Pin") { togglePin(task) }
            Button(task.isMuted ? "Unmute" : "Mute") { toggleMute(task) }
            Button("Archive") { archive(task) }
            Button("Mark done") { markDone(task) }
                .tint(BarkTheme.Palette.errorRed)
        }
        .buttonStyle(SecondaryCapsuleButtonStyle())
        .font(.caption.weight(.heavy))
    }

    // MARK: - View-model

    private func heroData(_ task: AgentTask) -> DetailHeroData {
        DetailHeroData(
            status: task.status,
            agentName: task.displayName,
            taskID: task.taskID,
            progressLabel: task.progress ?? "—",
            etaLabel: AgentCardData.etaLabel(from: task.eta) ?? task.status.label,
            updatedLabel: AgentCardData.relativeLabel(from: task.updatedAt)
        )
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
}
