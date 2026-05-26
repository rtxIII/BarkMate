//
//  AgentDashboardView.swift
//  BarkMate
//
//  V0.3 Phase 3.1 Agents tab。
//  AgentHeroCard (深色) + FilterStrip + LazyVGrid(2 列 AgentTaskCard) +
//  Demo push / Reconcile stale 按钮 + 底部 3 条 mini history。
//  Phase 3.1.5/3.1.6: Demo push 通过 PushArchiver 注入一条 v0.3 mock 推送
//  (toolbar bolt + 主区按钮共享同一动作),验证 NSE → SwiftData → @Query
//  闭环不依赖真实 APNs。
//

import SwiftUI
import SwiftData
import Factory
import Models
import Store
import BarkService
import DesignSystem

struct AgentDashboardView: View {

    @State private var refreshToken: Int = 0
    @State private var darwinObserver: DarwinObserver?
    @State private var selectedFilter: DashboardFilter = .all

    @Injected(\.pendingQueueDrainer) private var pendingQueueDrainer: PendingQueueDrainer
    @Injected(\.sharedModelContainer) private var modelContainer: ModelContainer
    @EnvironmentObject private var selectedTab: SelectedTab

    var body: some View {
        DashboardContent(
            filter: $selectedFilter,
            onRefresh: { await pendingQueueDrainer.drain() },
            onDemoPush: sendDemoPush,
            onGoToSetup: { selectedTab.current = .setup }
        )
        .id(refreshToken)
        .background(MockScreenBackground())
        .navigationTitle("Agents")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: sendDemoPush) {
                    Image(systemName: "bolt.badge.clock")
                }
                .accessibilityLabel("Send demo push")
            }
        }
        .onAppear { installDarwinObserver() }
        .onDisappear { darwinObserver = nil }
    }

    private func installDarwinObserver() {
        guard darwinObserver == nil else { return }
        darwinObserver = DarwinNotification.observe(.itemDidArrive) { @Sendable in
            Task { @MainActor in
                refreshToken &+= 1
            }
        }
    }

    /// 走 PushArchiver 注入一条 v0.3 mock 推送。逻辑封在 DemoPushInjector,
    /// 与 SetupView 的 "Send demo push" 按钮共用同一动作,保证状态机一致。
    private func sendDemoPush() {
        DemoPushInjector.injectNextStep(into: modelContainer)
        DarwinNotification.post(.itemDidArrive)
    }
}

// MARK: - Content

private struct DashboardContent: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AgentTask.updatedAt, order: .reverse)
    private var tasks: [AgentTask]

    @Query(
        filter: #Predicate<Memo> { $0.isArchived == false },
        sort: \Memo.createdAt,
        order: .reverse
    )
    private var memos: [Memo]

    @Binding var filter: DashboardFilter
    let onRefresh: @Sendable () async -> Void
    let onDemoPush: () -> Void
    let onGoToSetup: () -> Void

    private var activeTasks: [AgentTask] {
        tasks
            .filter { !$0.status.isTerminal && !$0.isArchived }
            .sorted(by: prioritySort)
    }

    private var filteredTasks: [AgentCardData] {
        activeTasks
            .filter { filter.matches($0.status) }
            .map(AgentCardData.fromTask)
    }

    private var counts: AgentHeroCounts {
        AgentHeroCounts(
            running: tasks.filter { !$0.isArchived && $0.status == .running }.count,
            waiting: tasks.filter { !$0.isArchived && $0.status == .waitingInput }.count,
            blocked: tasks.filter { !$0.isArchived && $0.status == .blocked }.count,
            failed: tasks.filter { !$0.isArchived && $0.status == .failed }.count,
            stale: tasks.filter { !$0.isArchived && $0.status == .stale }.count,
            done: tasks.filter { $0.status == .done }.count,
            active: tasks.filter { !$0.isArchived && !$0.status.isTerminal }.count
        )
    }

    private var historyPreview: [HistoryItemData] {
        let terminalTasks = tasks
            .filter { $0.status.isTerminal || $0.isArchived }
            .map(HistoryItemData.fromTask)
        let memoItems = memos.map(HistoryItemData.fromMemo)
        return (terminalTasks + memoItems)
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                AgentHeroCard(counts: counts)
                FilterStrip(selected: $filter)
                SectionTitle("Active Agents", trailing: "\(filteredTasks.count) cards")

                if filteredTasks.isEmpty {
                    EmptyDashboardState(onGoToSetup: onGoToSetup)
                } else {
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        ForEach(filteredTasks) { data in
                            NavigationLink {
                                AgentDetailView(taskID: data.id)
                            } label: {
                                AgentTaskCard(data: data)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { agentContextMenu(for: data.id) }
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        onDemoPush()
                    } label: {
                        Label("Demo push", systemImage: "bolt.fill")
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())

                    Button("Reconcile stale") { reconcileStale() }
                        .buttonStyle(SecondaryCapsuleButtonStyle())
                }

                if !historyPreview.isEmpty {
                    SectionTitle("History", trailing: "old Bark + memos")
                    VStack(spacing: 10) {
                        ForEach(historyPreview) { item in
                            HistoryMiniRow(data: item)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .refreshable { await onRefresh() }
    }

    @ViewBuilder
    private func agentContextMenu(for id: UUID) -> some View {
        if let task = tasks.first(where: { $0.id == id }) {
            Button(task.isPinned ? "Unpin" : "Pin") { togglePin(task) }
            Button(task.isMuted ? "Unmute" : "Mute") { toggleMute(task) }
            Button("Mark Done") { markDone(task) }
            Button("Archive") { archive(task) }
        }
    }

    /// Mock 契约 prioritySort:pinned → status.sortPriority → 字典序 displayName。
    /// (与 AgentMockPrototypeView.MockAgentTask.prioritySort 对齐;不再用 updatedAt
    /// 作为 tiebreak,以保证视觉位置稳定。)
    private func prioritySort(_ lhs: AgentTask, _ rhs: AgentTask) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
        if lhs.status.sortPriority != rhs.status.sortPriority {
            return lhs.status.sortPriority < rhs.status.sortPriority
        }
        return lhs.displayName < rhs.displayName
    }

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

    private func markDone(_ task: AgentTask) {
        task.status = .done
        task.updatedAt = .now
        try? modelContext.save()
    }

    private func archive(_ task: AgentTask) {
        task.isArchived = true
        task.updatedAt = .now
        try? modelContext.save()
    }

    private func reconcileStale() {
        let threshold: TimeInterval = 30 * 60
        let now = Date.now
        for task in tasks where task.status == .running && !task.isArchived {
            if now.timeIntervalSince(task.updatedAt) > threshold {
                task.status = .stale
            }
        }
        try? modelContext.save()
    }
}

// MARK: - FilterStrip

private struct FilterStrip: View {
    @Binding var selected: DashboardFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DashboardFilter.allCases) { filter in
                    Button(filter.title) { selected = filter }
                        .buttonStyle(ChipButtonStyle(isSelected: selected == filter))
                }
            }
        }
    }
}

enum DashboardFilter: String, Identifiable, CaseIterable {
    case all
    case attention
    case running
    case blocked
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .attention: return "Needs attention"
        case .running: return "Running"
        case .blocked: return "Blocked"
        case .done: return "Done"
        }
    }

    func matches(_ status: AgentStatus) -> Bool {
        switch self {
        case .all: return true
        case .attention: return [.waitingInput, .blocked, .failed].contains(status)
        case .running: return status == .running
        case .blocked: return status == .blocked
        case .done: return status == .done
        }
    }
}

// MARK: - Empty

private struct EmptyDashboardState: View {
    let onGoToSetup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Pill("first push", dark: true)
            Text("Send one push. Get one living card.")
                .font(BarkTheme.Typography.heroSerif(size: 28))
                .tracking(-1)
                .foregroundStyle(.white)
            Text("Setup tab 里有 curl 模板,带上 agent_status + task_id 即可。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.66))
                .lineSpacing(3)
            Button("Open Setup tab", action: onGoToSetup)
                .buttonStyle(PrimaryCapsuleButtonStyle())
                .padding(.top, 4)
        }
        .padding(18)
        .heroBackground(decorationColor: BarkTheme.Palette.warningYellow.opacity(0.34))
    }
}

// MARK: - View-model bridging

extension AgentCardData {
    static func fromTask(_ task: AgentTask) -> AgentCardData {
        AgentCardData(
            id: task.id,
            agentName: task.displayName,
            taskID: task.taskID,
            status: task.status,
            latestStep: task.latestStepTitle ?? "No step yet",
            progressLabel: task.progress,
            progressFraction: Self.progressFraction(from: task.progress),
            etaLabel: Self.etaLabel(from: task.eta),
            updatedLabel: Self.relativeLabel(from: task.updatedAt),
            isPinned: task.isPinned,
            isMuted: task.isMuted
        )
    }

    static func progressFraction(from raw: String?) -> Double? {
        guard let raw else { return nil }
        if raw.contains("/") {
            let parts = raw.split(separator: "/")
            if parts.count == 2,
               let num = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let den = Double(parts[1].trimmingCharacters(in: .whitespaces)),
               den > 0 {
                return min(1, num / den)
            }
        }
        if raw.hasSuffix("%"),
           let pct = Double(raw.dropLast().trimmingCharacters(in: .whitespaces)) {
            return min(1, pct / 100)
        }
        return nil
    }

    static func etaLabel(from date: Date?) -> String? {
        guard let date else { return nil }
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "now" }
        let minutes = Int(interval / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }

    static func relativeLabel(from date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "now" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

extension HistoryItemData {
    static func fromTask(_ task: AgentTask) -> HistoryItemData {
        HistoryItemData(
            id: task.id,
            kind: .agent,
            kindBadge: task.isArchived ? "archived" : task.status.label,
            title: task.displayName,
            body: task.latestStepTitle ?? "Completed agent task",
            updatedAt: task.updatedAt
        )
    }

    static func fromMemo(_ memo: Memo) -> HistoryItemData {
        HistoryItemData(
            id: memo.id,
            kind: memo.source == .incoming ? .incoming : .memo,
            kindBadge: memo.source == .incoming ? "incoming" : "memo",
            title: memo.title ?? (memo.source == .incoming ? "Push" : "Memo"),
            body: memo.body,
            updatedAt: memo.updatedAt
        )
    }
}
