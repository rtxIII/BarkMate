//
//  SearchView.swift
//  BarkAgent
//
//  V0.4 Day 7 — Mission Control 重写。
//  MCConsoleHeader + MC search input(amber 左 4pt + > prompt + 闪烁 caret)
//  + MCChip scope/filter chips + s-meta 结果计数 + MCResultRow。
//  数据流(SearchEngine / SearchQuery / facets / runSearch)保持不变。
//

import SwiftUI
import SwiftData
import Models
import BarkService
import DesignSystem

struct SearchView: View {

    @Environment(\.modelContext) private var modelContext

    @State private var queryText: String = ""
    @State private var selectedScope: ScopeChip = .all
    /// 多选 status filter chips。空 = 不过滤(对齐 mock B 第二行 "+ wait / + stuck / + fail / + done")。
    @State private var statusChips: Set<AgentStatus> = []
    @State private var agentFilter: String? = nil
    @State private var dateFilter: DateRangeFilter = .all
    @State private var results: [SearchResult] = []
    @State private var facets: SearchEngine.Facets = .init(agentIDs: [])
    @FocusState private var inputFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MCConsoleHeader(
                    crumbs: ["SYS", "SEARCH", crumbQuery],
                    title: "Search"
                ) {
                    MCIconButton("⌘") { inputFocused = true }
                }
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 12) {
                    searchInput

                    chipScope

                    chipStatusRow

                    chipFilters

                    if shouldShowEmpty {
                        emptyState
                        savedQueriesSection
                    } else if results.isEmpty {
                        noResults
                    } else {
                        resultsList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .mcScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loadFacets() }
        .onChange(of: queryText) { _, _ in runSearch() }
        .onChange(of: selectedScope) { _, _ in runSearch() }
        .onChange(of: statusChips) { _, _ in runSearch() }
        .onChange(of: agentFilter) { _, _ in runSearch() }
        .onChange(of: dateFilter) { _, _ in runSearch() }
    }

    // MARK: - Search input

    private var searchInput: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(">")
                .font(MissionControl.Font.jetBrainsMono(size: 18, weight: .bold))
                .foregroundStyle(MissionControl.Color.amber)

            TextField(
                "",
                text: $queryText,
                prompt: Text("agents, steps, pushes")
                    .foregroundColor(MissionControl.Color.inkMute)
            )
            .textFieldStyle(.plain)
            .focused($inputFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(MissionControl.Font.jetBrainsMono(size: 16, weight: .regular))
            .foregroundStyle(MissionControl.Color.ink)
            .tracking(-0.32)

            if !queryText.isEmpty {
                Button("CLEAR") { queryText = "" }
                    .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(MissionControl.Color.inkSoft)
            }
        }
        .padding(14)
        .background(MissionControl.Color.hull)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(MissionControl.Color.amber)
                .frame(width: 4)
        }
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
        )
    }

    // MARK: - Chips

    private var chipScope: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ScopeChip.allCases) { scope in
                    MCChip(scope.title, isActive: selectedScope == scope) {
                        selectedScope = scope
                    }
                }
            }
        }
    }

    /// Mock B 第二行的彩色 status filter chips。多选 toggle。
    /// 颜色与 MissionControl.Status.render 对齐:wait=amber / stuck=orange / fail=magenta / done=lime。
    private var chipStatusRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(StatusFilterChip.allCases) { chip in
                    let isOn = statusChips.contains(chip.status)
                    MCChip(
                        chip.label,
                        isActive: isOn,
                        tint: chip.tint
                    ) {
                        if isOn {
                            statusChips.remove(chip.status)
                        } else {
                            statusChips.insert(chip.status)
                        }
                    }
                }
            }
        }
    }

    /// Agent / Date 过滤保留 Menu 形式;mock B 把它们隐藏到 Saved queries 但
    /// 实际数据驱动还是需要 picker。两个 chip 用 .mcPill 样式。
    private var chipFilters: some View {
        HStack(spacing: 6) {
            Menu {
                Button("all") { agentFilter = nil }
                ForEach(facets.agentIDs, id: \.self) { agentID in
                    Button(agentID) { agentFilter = agentID }
                }
            } label: {
                filterPillLabel("agent: \(agentFilter ?? "all")")
            }

            Menu {
                Picker("Date", selection: $dateFilter) {
                    ForEach(DateRangeFilter.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
            } label: {
                filterPillLabel(dateFilter.label)
            }
        }
    }

    private func filterPillLabel(_ text: String) -> some View {
        Text(text)
            .mcPill()
    }

    /// Mock B 的 Saved queries 段。点击预设过滤组合。
    @ViewBuilder
    private var savedQueriesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MCSectionHeader("Saved queries", trailing: "jump to")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    MCChip("Stuck on…", isActive: false) {
                        statusChips = [.blocked]
                    }
                    MCChip("Fails · 7d", isActive: false) {
                        statusChips = [.failed]
                        dateFilter = .last7d
                    }
                    MCChip("All wait", isActive: false) {
                        statusChips = [.waitingInput]
                    }
                    MCChip("Reset", isActive: false) {
                        statusChips = []
                        agentFilter = nil
                        dateFilter = .all
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Results

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(metaLabel)
                .font(MissionControl.Font.jetBrainsMono(size: 9.5, weight: .bold))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(MissionControl.Color.inkSoft)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(MissionControl.Color.rule)
                        .frame(height: MissionControl.Border.hairline)
                }

            VStack(spacing: 0) {
                // 边遍历边追踪已经显示过的 task UUID;遇到 step 且 task UUID 已显示 → 嵌套样式。
                let nestingFlags = computeNestingFlags(results)
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    MCResultRow(
                        kind: kind(for: result),
                        title: title(for: result),
                        body: body(for: result),
                        query: queryText,
                        timeLabel: timeLabel(for: result),
                        isNested: nestingFlags[index]
                    )
                }
            }
        }
        .padding(.top, 4)
    }

    /// 计算每个 result 是否嵌套:step 且其 task 已在前面 result 中显示过。
    private func computeNestingFlags(_ results: [SearchResult]) -> [Bool] {
        var shownTaskIDs: Set<UUID> = []
        var flags: [Bool] = []
        for result in results {
            switch result {
            case .agent(let task):
                shownTaskIDs.insert(task.id)
                flags.append(false)
            case .step(let step):
                if let tid = step.task?.id, shownTaskIDs.contains(tid) {
                    flags.append(true)
                } else {
                    if let tid = step.task?.id { shownTaskIDs.insert(tid) }
                    flags.append(false)
                }
            case .inbox:
                flags.append(false)
            }
        }
        return flags
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("— READY —")
                .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(MissionControl.Color.inkSoft)
            Text("Search agent cards, step history, and incoming pushes.")
                .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                .foregroundStyle(MissionControl.Color.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MissionControl.Color.hull)
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
        )
        .padding(.top, 8)
    }

    private var noResults: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("[ NO HITS ]")
                .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .bold))
                .foregroundStyle(MissionControl.Color.magenta)
            Text("Nothing matched the current filters.")
                .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                .foregroundStyle(MissionControl.Color.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MissionControl.Color.hull)
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
        )
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var shouldShowEmpty: Bool {
        queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasActiveFilters
    }

    private var hasActiveFilters: Bool {
        !statusChips.isEmpty || agentFilter != nil || dateFilter != .all
    }

    private var crumbQuery: String {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Q · IDLE" }
        return "Q · \(trimmed.uppercased().prefix(12))"
    }

    private var metaLabel: String {
        let n = results.count
        let nLabel = n < 10 ? "0\(n)" : "\(n)"
        return "— \(nLabel) HITS —"
    }

    private func kind(for result: SearchResult) -> MCResultRow.Kind {
        switch result {
        case .agent: return .agent
        case .step: return .step
        case .inbox: return .incoming
        }
    }

    private func title(for result: SearchResult) -> String {
        switch result {
        case .agent(let t): return t.displayName
        case .step(let s): return s.title ?? s.task?.displayName ?? "Step"
        case .inbox(let i): return i.title ?? "Push"
        }
    }

    private func body(for result: SearchResult) -> String {
        switch result {
        case .agent(let t): return t.latestStepTitle ?? t.progress ?? t.statusRaw
        case .step(let s): return s.body
        case .inbox(let i): return i.body
        }
    }

    private func timeLabel(for result: SearchResult) -> String {
        let date: Date
        switch result {
        case .agent(let t): date = t.updatedAt
        case .step(let s): date = s.createdAt
        case .inbox(let i): date = i.updatedAt
        }
        if Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        }
        return date.formatted(.dateTime.month(.abbreviated).day(.twoDigits))
    }

    private func loadFacets() {
        facets = (try? SearchEngine.availableFacets(in: modelContext)) ?? .init(agentIDs: [])
    }

    private func runSearch() {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && !hasActiveFilters {
            results = []
            return
        }
        let query = SearchQuery(
            text: trimmed,
            scope: selectedScope.scope,
            agentIDs: agentFilter.map { Set([$0]) } ?? [],
            statuses: statusChips,
            dateRange: dateFilter.range
        )
        do {
            results = try SearchEngine.search(query, in: modelContext)
        } catch {
            results = []
        }
    }
}

private enum ScopeChip: String, Identifiable, CaseIterable {
    case all, agents, steps, inbox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .agents: return "Agents"
        case .steps: return "Steps"
        case .inbox: return "Inbox"
        }
    }

    var scope: SearchScope {
        switch self {
        case .all: return .all
        case .agents: return .agents
        case .steps: return .steps
        case .inbox: return .inbox
        }
    }
}

/// Mock B 第二行 status filter chip 模型。
/// 4 个 chip 对应 4 种用户最常筛选的状态;颜色与 MissionControl.Status.render 一致。
private enum StatusFilterChip: String, Identifiable, CaseIterable {
    case wait, stuck, fail, done

    var id: String { rawValue }

    var status: AgentStatus {
        switch self {
        case .wait: return .waitingInput
        case .stuck: return .blocked
        case .fail: return .failed
        case .done: return .done
        }
    }

    /// Chip 前缀 + label。 mock B `+ wait` 表示"添加此 filter"。
    var label: String {
        switch self {
        case .wait: return "+ wait"
        case .stuck: return "+ stuck"
        case .fail: return "+ fail"
        case .done: return "+ done"
        }
    }

    var tint: Color {
        switch self {
        case .wait: return MissionControl.Color.amber
        case .stuck: return MissionControl.Color.orange
        case .fail: return MissionControl.Color.magenta
        case .done: return MissionControl.Color.lime
        }
    }
}

private enum DateRangeFilter: String, Identifiable, CaseIterable {
    case all, today, last7d, last30d

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "any time"
        case .today: return "today"
        case .last7d: return "last 7d"
        case .last30d: return "last 30d"
        }
    }

    var range: ClosedRange<Date>? {
        let now = Date.now
        switch self {
        case .all: return nil
        case .today:
            let start = Calendar.current.startOfDay(for: now)
            return start...now
        case .last7d:
            return now.addingTimeInterval(-7 * 24 * 3600)...now
        case .last30d:
            return now.addingTimeInterval(-30 * 24 * 3600)...now
        }
    }
}
