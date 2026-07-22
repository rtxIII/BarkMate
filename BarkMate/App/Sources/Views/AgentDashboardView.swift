//
//  AgentDashboardView.swift
//  BarkAgent
//
//  V0.4 Day 5 — Mission Control 重写。
//  布局:MCHeadsUpPanel + 三段 bucket(Needs you / Running / Settled),每段按
//  project(agentID)分组;多 session 组用 MCProjectGroupCard 折叠,单 session 退化原生卡。
//  数据流(@Query / @Injected / DemoPush / DarwinObserver)保持不变。
//  FilterStrip / EmptyDashboardState 旧组件不再使用,因为 bucket 分组替代了 filter,
//  empty 状态走 needsYou+running+settled 总数为 0 的判定。
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
    /// 展开的 project 组名集合。托管在此(而非 DashboardContent),因为后者随
    /// `.id(refreshToken)` 在每次推送到达时被整体重建,内部 @State 会被丢弃。
    @State private var expandedProjects: Set<String> = []

    @Injected(\.pendingQueueDrainer) private var pendingQueueDrainer: PendingQueueDrainer
    @Injected(\.sharedModelContainer) private var modelContainer: ModelContainer
    @EnvironmentObject private var selectedTab: SelectedTab

    var body: some View {
        DashboardContent(
            expandedProjects: $expandedProjects,
            onRefresh: { await pendingQueueDrainer.drain() },
            onDemoPush: sendDemoPush,
            onGoToSetup: { selectedTab.requestSetupGuide() }
        )
        .id(refreshToken)
        .mcScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
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

    @Injected(\.staleTimeoutStore) private var staleTimeoutStore: StaleTimeoutStore

    @Query(sort: \AgentTask.updatedAt, order: .reverse)
    private var tasks: [AgentTask]

    @Query(
        filter: #Predicate<AgentInboxItem> { $0.isArchived == false },
        sort: \AgentInboxItem.createdAt,
        order: .reverse
    )
    private var inboxItems: [AgentInboxItem]

    @Binding var expandedProjects: Set<String>
    let onRefresh: @Sendable () async -> Void
    let onDemoPush: () -> Void
    let onGoToSetup: () -> Void

    /// 派生有效状态:running 超过阈值 → stale。视图渲染时按 now 惰性计算。
    private func effective(_ task: AgentTask) -> AgentStatus {
        task.effectiveStatus(now: Date(), threshold: staleTimeoutStore.threshold())
    }

    private var activeTasks: [AgentTask] {
        tasks
            .filter { !effective($0).isTerminal && !$0.isArchived }
            .sorted(by: prioritySort)
    }

    private var needsYouTasks: [AgentCardData] {
        activeTasks
            .filter { effective($0).mcBucket == .needsYou }
            .map { AgentCardData.fromTask($0, status: effective($0)) }
    }

    private var runningTasks: [AgentCardData] {
        activeTasks
            .filter { effective($0).mcBucket == .running }
            .map { AgentCardData.fromTask($0, status: effective($0)) }
    }

    private var settledDoneTasks: [AgentCardData] {
        tasks
            .filter { !$0.isArchived && effective($0) == .done }
            .map { AgentCardData.fromTask($0, status: effective($0)) }
    }

    private var settledFailedTasks: [AgentCardData] {
        tasks
            .filter { !$0.isArchived && effective($0) == .failed }
            .map { AgentCardData.fromTask($0, status: effective($0)) }
    }

    // MARK: - Project grouping

    /// 把已按 prioritySort 排好序的扁平卡数组,按 project(agentName)聚拢成组。
    /// 组的先后顺序 = 该组内最高优先级卡在原数组中的首次出现位置,
    /// 组内顺序沿用原数组顺序(即 prioritySort)。单 session 组由视图层退化为原生卡。
    private func groupByProject(_ cards: [AgentCardData]) -> [AgentProjectGroup] {
        var order: [String] = []
        var buckets: [String: [AgentCardData]] = [:]
        for card in cards {
            if buckets[card.agentName] == nil {
                order.append(card.agentName)
            }
            buckets[card.agentName, default: []].append(card)
        }
        return order.map { AgentProjectGroup(projectName: $0, cards: buckets[$0] ?? []) }
    }

    private var needsYouGroups: [AgentProjectGroup] { groupByProject(needsYouTasks) }
    private var runningGroups: [AgentProjectGroup] { groupByProject(runningTasks) }
    private var settledDoneGroups: [AgentProjectGroup] { groupByProject(settledDoneTasks) }
    private var settledFailedGroups: [AgentProjectGroup] { groupByProject(settledFailedTasks) }

    private func expandedBinding(for project: String) -> Binding<Bool> {
        Binding(
            get: { expandedProjects.contains(project) },
            set: { isOn in
                if isOn { expandedProjects.insert(project) }
                else { expandedProjects.remove(project) }
            }
        )
    }

    private var counts: AgentHeroCounts {
        AgentHeroCounts(
            running: tasks.filter { !$0.isArchived && effective($0) == .running }.count,
            waiting: tasks.filter { !$0.isArchived && effective($0) == .waitingInput }.count,
            blocked: tasks.filter { !$0.isArchived && effective($0) == .blocked }.count,
            failed: tasks.filter { !$0.isArchived && effective($0) == .failed }.count,
            stale: tasks.filter { !$0.isArchived && effective($0) == .stale }.count,
            done: tasks.filter { effective($0) == .done }.count,
            active: tasks.filter { !$0.isArchived && !effective($0).isTerminal }.count
        )
    }

    private var historyPreview: [HistoryItemData] {
        let terminalTasks = tasks
            .filter { effective($0).isTerminal || $0.isArchived }
            .map { HistoryItemData.fromTask($0, status: effective($0)) }
        let inboxRows = inboxItems.map(HistoryItemData.fromInboxItem)
        return (terminalTasks + inboxRows)
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)
            .map { $0 }
    }

    private var isEmpty: Bool {
        needsYouTasks.isEmpty && runningTasks.isEmpty && settledDoneTasks.isEmpty && settledFailedTasks.isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    MCHeadsUpPanel(counts: counts)
                        .padding(.bottom, 6)

                    if isEmpty {
                        emptyState
                        emptyStateTips
                    } else {
                        bucketSections
                    }

                    if !historyPreview.isEmpty {
                        MCSectionHeader("History", trailing: "incoming pushes")
                        VStack(spacing: 0) {
                            ForEach(historyPreview) { item in
                                HistoryMiniRow(data: item, style: .missionControl)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .refreshable { await onRefresh() }
    }

    // MARK: - Bucket sections

    @ViewBuilder
    private var bucketSections: some View {
        if !needsYouGroups.isEmpty {
            MCSectionHeader("Needs you", trailing: cardsLabel(needsYouTasks.count))
            VStack(spacing: 10) {
                ForEach(needsYouGroups) { group in
                    projectGroupView(group, rowStyle: .attention)
                }
            }
        }

        if !runningGroups.isEmpty {
            MCSectionHeader("Running", trailing: agentsLabel(runningTasks.count))
            VStack(spacing: 10) {
                ForEach(runningGroups) { group in
                    projectGroupView(group, rowStyle: .compact)
                }
            }
        }

        if !settledDoneGroups.isEmpty || !settledFailedGroups.isEmpty {
            MCSectionHeader("Settled", trailing: settledTrailingLabel)
            VStack(spacing: 10) {
                ForEach(settledDoneGroups) { group in
                    projectGroupView(group, rowStyle: .compact)
                }
            }
            // mock B 把 fail 卡放 Settled 段,用 MCAttentionCard.stuck 视觉(橙色 marker)显示。
            if !settledFailedGroups.isEmpty {
                VStack(spacing: 10) {
                    ForEach(settledFailedGroups) { group in
                        projectGroupView(group, rowStyle: .attention)
                    }
                }
                .padding(.top, settledDoneGroups.isEmpty ? 0 : 10)
            }
        }
    }

    /// 组内单卡样式:needs-you / fail 段用大 attention 卡,running / done 段用紧凑行。
    private enum GroupRowStyle {
        case attention
        case compact
    }

    /// 渲染一个 project 组:
    ///   - 多 session(isCollapsible)→ MCProjectGroupCard(可折叠,展开态列 MCSessionRow)。
    ///   - 单 session → 退化为原生卡(保持既有 UITest 文案断言不破)。
    @ViewBuilder
    private func projectGroupView(_ group: AgentProjectGroup, rowStyle: GroupRowStyle) -> some View {
        if group.isCollapsible {
            MCProjectGroupCard(group: group, isExpanded: expandedBinding(for: group.projectName)) { card in
                NavigationLink {
                    AgentDetailView(taskID: card.id)
                } label: {
                    MCSessionRow(data: card)
                }
                .buttonStyle(.plain)
                .contextMenu { agentContextMenu(for: card.id) }
            }
        } else if let card = group.leadCard {
            NavigationLink {
                AgentDetailView(taskID: card.id)
            } label: {
                switch rowStyle {
                case .attention: MCAttentionCard(data: card)
                case .compact: MCRunCompactRow(data: card)
                }
            }
            .buttonStyle(.plain)
            .contextMenu { agentContextMenu(for: card.id) }
        }
    }

    private var settledTrailingLabel: String {
        var parts: [String] = []
        if !settledDoneTasks.isEmpty { parts.append("\(countLabel(settledDoneTasks.count)) done") }
        if !settledFailedTasks.isEmpty { parts.append("\(countLabel(settledFailedTasks.count)) fail") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("— NO AGENTS YET —")
                .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(MissionControl.Color.inkSoft)
            Text("Send one push. Get one living card.")
                .font(MissionControl.Font.interTight(size: 22, weight: .heavy))
                .tracking(-0.66)
                .foregroundStyle(MissionControl.Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Open Settings → Setup guide for a curl template.")
                .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(MissionControl.Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            emptyStateActions
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MissionControl.Color.hull)
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
        )
        .padding(.vertical, 14)
    }

    private var emptyStateActions: some View {
        HStack(spacing: 8) {
            Button(action: onDemoPush) {
                Text("Send demo push")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MCPrimaryButtonStyle())
            .accessibilityIdentifier("dashboard-send-demo-push")

            Button(action: onGoToSetup) {
                Text("Setup guide")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MCGhostButtonStyle())
            .accessibilityIdentifier("dashboard-setup-guide")
        }
        .padding(.top, 6)
    }

    /// emptyState 下方的 tip section,用 mock B 风格的 "▸ TELEMETRY" 块
    /// 填充原本空白的视口下半部,呈现真实数据进来后的预期形态。
    private var emptyStateTips: some View {
        VStack(alignment: .leading, spacing: 12) {
            MCSectionHeader("Telemetry", trailing: "live · 0 pkt")

            VStack(alignment: .leading, spacing: 10) {
                tipRow(code: "[ APNS ]", color: MissionControl.Color.cyan,
                       title: "Awaiting first device token")
                tipRow(code: "[ STORE ]", color: MissionControl.Color.lime,
                       title: "SwiftData ready, schema v0.4 frozen")
                tipRow(code: "[ HINT ]", color: MissionControl.Color.amber,
                       title: "Send a curl with agent_status to spawn the first card")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MissionControl.Color.hull)
            .overlay(
                Rectangle()
                    .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
            )
        }
        .padding(.top, 4)
    }

    private func tipRow(code: String, color: Color, title: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(code)
                .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay(
                    Rectangle()
                        .stroke(color, lineWidth: MissionControl.Border.hairline)
                )
            Text(title)
                .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(MissionControl.Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private func cardsLabel(_ n: Int) -> String {
        n < 10 ? "0\(n) cards" : "\(n) cards"
    }

    private func agentsLabel(_ n: Int) -> String {
        n < 10 ? "0\(n) agents" : "\(n) agents"
    }

    private func countLabel(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }

    @ViewBuilder
    private func agentContextMenu(for id: UUID) -> some View {
        if let task = tasks.first(where: { $0.id == id }) {
            ShareLink(item: AgentShareSnippet.text(from: AgentCardData.fromTask(task, status: effective(task)))) {
                Label("Share status", systemImage: "square.and.arrow.up")
            }
            Button(task.isPinned ? "Unpin" : "Pin") { togglePin(task) }
            Button(task.isMuted ? "Unmute" : "Mute") { toggleMute(task) }
            Button("Mark Done") { markDone(task) }
            Button("Archive") { archive(task) }
        }
    }

    /// Mock 契约 prioritySort:pinned → status.sortPriority → 字典序 displayName。
    private func prioritySort(_ lhs: AgentTask, _ rhs: AgentTask) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
        let lp = effective(lhs).sortPriority
        let rp = effective(rhs).sortPriority
        if lp != rp { return lp < rp }
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
}

// MARK: - MC button styles (本屏内联;P5/P6 可能也用到,后续视情况下沉)

struct MCPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(MissionControl.Color.void)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(configuration.isPressed
                        ? MissionControl.Color.amber.opacity(0.8)
                        : MissionControl.Color.amber)
            .overlay(
                Rectangle()
                    .stroke(MissionControl.Color.amber, lineWidth: 1)
            )
    }
}

struct MCGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(configuration.isPressed
                             ? MissionControl.Color.amber
                             : MissionControl.Color.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(MissionControl.Color.hull)
            .overlay(
                Rectangle()
                    .stroke(MissionControl.Color.ruleHot, lineWidth: 1)
            )
    }
}

// MARK: - View-model bridging

extension AgentCardData {
    static func fromTask(_ task: AgentTask, status: AgentStatus) -> AgentCardData {
        AgentCardData(
            id: task.id,
            agentName: task.displayName,
            taskID: task.taskID,
            status: status,
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
    /// Mock B 的 badge 命名:
    ///   - stale → [ STALE ] (kind = .stale, 时间衰退色)
    ///   - failed → [ AGT-FAIL ]
    ///   - done / 其它 archived → [ AGT-DONE ]
    static func fromTask(_ task: AgentTask, status: AgentStatus) -> HistoryItemData {
        let kind: HistoryItemKind
        let badge: String
        switch status {
        case .stale:
            kind = .stale
            badge = "stale"
        case .failed:
            kind = .agent
            badge = "agt-fail"
        default:
            kind = .agent
            badge = "agt-done"
        }
        return HistoryItemData(
            id: task.id,
            kind: kind,
            kindBadge: badge,
            title: task.displayName,
            body: task.latestStepTitle ?? "Completed agent task",
            updatedAt: task.updatedAt
        )
    }

    /// 旧 Bark 协议推送 → mock B `[ BARK ]` 青色徽章。
    static func fromInboxItem(_ item: AgentInboxItem) -> HistoryItemData {
        HistoryItemData(
            id: item.id,
            kind: .incoming,
            kindBadge: "bark",
            title: item.title ?? "Push",
            body: item.body,
            updatedAt: item.updatedAt
        )
    }
}
