//
//  SearchView.swift
//  BarkMate
//
//  V0.3 Phase 3.5 / 4.11 Search tab。MockSearchFieldStyle + ChipButtonStyle scope chips +
//  真过滤 pickers (status / agent / dateRange) + 三表联合搜索结果。数据走
//  BarkService.SearchEngine,视觉对齐 AgentMockSearchView。
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
    @State private var statusFilter: AgentStatusFilter = .all
    @State private var agentFilter: String? = nil
    @State private var dateFilter: DateRangeFilter = .all
    @State private var results: [SearchResult] = []
    @State private var facets: SearchEngine.Facets = .init(tags: [], agentIDs: [])

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Search agents, steps, memos", text: $queryText)
                    .textFieldStyle(MockSearchFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ScopeChip.allCases) { scope in
                            Button(scope.title) { selectedScope = scope }
                                .buttonStyle(ChipButtonStyle(isSelected: selectedScope == scope))
                        }
                    }
                }

                filterRow

                if queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !hasActiveFilters {
                    emptyState
                } else if results.isEmpty {
                    noResults
                } else {
                    VStack(spacing: 10) {
                        ForEach(results, id: \.id) { result in
                            SearchResultRow(result: result, query: queryText)
                        }
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .background(MockScreenBackground())
        .navigationTitle("Search")
        .onAppear { loadFacets() }
        .onChange(of: queryText) { _, _ in runSearch() }
        .onChange(of: selectedScope) { _, _ in runSearch() }
        .onChange(of: statusFilter) { _, _ in runSearch() }
        .onChange(of: agentFilter) { _, _ in runSearch() }
        .onChange(of: dateFilter) { _, _ in runSearch() }
    }

    @ViewBuilder
    private var filterRow: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Status", selection: $statusFilter) {
                    ForEach(AgentStatusFilter.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
            } label: {
                Pill("status: \(statusFilter.label)")
            }

            Menu {
                Button("all") { agentFilter = nil }
                ForEach(facets.agentIDs, id: \.self) { agentID in
                    Button(agentID) { agentFilter = agentID }
                }
            } label: {
                Pill("agent: \(agentFilter ?? "all")")
            }

            Menu {
                Picker("Date", selection: $dateFilter) {
                    ForEach(DateRangeFilter.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
            } label: {
                Pill(dateFilter.label)
            }
        }
    }

    private var emptyState: some View {
        Text("Search agent cards, step history, and memos.")
            .font(.subheadline)
            .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
            .mockCardPadding()
    }

    private var noResults: some View {
        Text("Nothing matched the current filters.")
            .font(.subheadline)
            .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
            .mockCardPadding()
    }

    private var hasActiveFilters: Bool {
        statusFilter != .all || agentFilter != nil || dateFilter != .all
    }

    private func loadFacets() {
        facets = (try? SearchEngine.availableFacets(in: modelContext)) ?? .init(tags: [], agentIDs: [])
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
            statuses: Set(statusFilter.statuses),
            dateRange: dateFilter.range
        )
        do {
            results = try SearchEngine.search(query, in: modelContext)
        } catch {
            results = []
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    let query: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Pill(kindLabel)
                HighlightedText(title, highlight: query, lineLimit: 1)
                    .font(.headline.weight(.heavy))
                HighlightedText(bodyText, highlight: query, lineLimit: 3)
                    .font(.subheadline)
                    .foregroundStyle(BarkTheme.Palette.ink.opacity(0.60))
            }
            Spacer()
            if let status {
                StatusBadge(status: status, compact: true)
            }
        }
        .mockCardPadding()
    }

    private var kindLabel: String {
        switch result {
        case .agent: return "agent"
        case .step: return "step"
        case .memo(let m): return m.source == .incoming ? "incoming" : "memo"
        }
    }

    private var title: String {
        switch result {
        case .agent(let t): return t.displayName
        case .step(let s): return s.title ?? s.task?.displayName ?? "Step"
        case .memo(let m): return m.title ?? (m.source == .incoming ? "Push" : "Memo")
        }
    }

    private var bodyText: String {
        switch result {
        case .agent(let t): return t.latestStepTitle ?? t.progress ?? t.statusRaw
        case .step(let s): return s.body
        case .memo(let m): return m.body
        }
    }

    private var status: AgentStatus? {
        switch result {
        case .agent(let t): return t.status
        case .step(let s): return s.status
        case .memo: return nil
        }
    }
}

private enum ScopeChip: String, Identifiable, CaseIterable {
    case all, agents, steps, memos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .agents: return "Agents"
        case .steps: return "Steps"
        case .memos: return "Memos"
        }
    }

    var scope: SearchScope {
        switch self {
        case .all: return .all
        case .agents: return .agents
        case .steps: return .steps
        case .memos: return .memos
        }
    }
}

/// 单选状态 filter:`.all` 不过滤;`.attention` 聚合 waitingInput / blocked / failed
/// 与 Dashboard FilterStrip 一致。
private enum AgentStatusFilter: String, Identifiable, CaseIterable {
    case all, running, waiting, blocked, failed, done, stale, attention

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "all"
        case .running: return "running"
        case .waiting: return "waiting"
        case .blocked: return "blocked"
        case .failed: return "failed"
        case .done: return "done"
        case .stale: return "stale"
        case .attention: return "needs attention"
        }
    }

    var statuses: [AgentStatus] {
        switch self {
        case .all: return []
        case .running: return [.running]
        case .waiting: return [.waitingInput]
        case .blocked: return [.blocked]
        case .failed: return [.failed]
        case .done: return [.done]
        case .stale: return [.stale]
        case .attention: return [.waitingInput, .blocked, .failed]
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

