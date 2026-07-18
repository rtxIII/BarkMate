//
//  HistoryView.swift
//  BarkAgent
//
//  V0.4 Day 7 — Mission Control 重写。
//  MCConsoleHeader + MCChip filter + 按日期分组 MCSectionHeader + HistoryRow(MC)。
//  数据流:archived AgentTask + incoming AgentInboxItem。
//

import SwiftUI
import SwiftData
import Models
import DesignSystem

struct HistoryView: View {

    @Query(sort: \AgentTask.updatedAt, order: .reverse)
    private var tasks: [AgentTask]

    @Query(sort: \AgentInboxItem.createdAt, order: .reverse)
    private var inboxItems: [AgentInboxItem]

    @State private var filter: HistoryFilter = .all

    /// status == .stale 的 task。mock B 顶部 STALE AGENTS heads-up 段独立展示,
    /// 不混入下方 timeline。
    private var staleTasks: [AgentTask] {
        tasks.filter { !$0.isArchived && $0.status == .stale }
    }

    private var items: [HistoryItemData] {
        // mock B 顶部 STALE 段独立高亮, 但 timeline 仍包含 stale 行(双重显示是有意的)。
        let archivedTasks = tasks
            .filter { $0.status.isTerminal || $0.isArchived || $0.status == .stale }
            .map(HistoryItemData.fromTask)
        let inboxRows = inboxItems.map(HistoryItemData.fromInboxItem)
        let merged = (archivedTasks + inboxRows)
            .filter(filter.matches)
            .sorted { $0.updatedAt > $1.updatedAt }
        return merged
    }

    /// 按日期分组:Today / Yesterday / Earlier · MMM dd。
    private var groupedItems: [(String, [HistoryItemData])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: items) { item -> String in
            if calendar.isDateInToday(item.updatedAt) {
                return "Today"
            } else if calendar.isDateInYesterday(item.updatedAt) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "'Earlier · 'MMM dd"
                return formatter.string(from: item.updatedAt)
            }
        }
        let order = ["Today", "Yesterday"]
        return groups.sorted { lhs, rhs in
            if order.contains(lhs.key) && order.contains(rhs.key) {
                return order.firstIndex(of: lhs.key)! < order.firstIndex(of: rhs.key)!
            }
            if order.contains(lhs.key) { return true }
            if order.contains(rhs.key) { return false }
            return (lhs.value.first?.updatedAt ?? .distantPast) > (rhs.value.first?.updatedAt ?? .distantPast)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MCConsoleHeader(
                    crumbs: ["SYS", "HISTORY", monthLabel],
                    title: "History"
                )
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 0) {
                    if !staleTasks.isEmpty {
                        staleHeadsUp
                            .padding(.bottom, 12)
                    }

                    filterRow
                        .padding(.bottom, 10)

                    if items.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedItems, id: \.0) { group in
                            MCSectionHeader(group.0, trailing: itemsLabel(group.1.count))
                            VStack(spacing: 0) {
                                ForEach(group.1) { item in
                                    HistoryRow(data: item, style: .missionControl)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .mcScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(HistoryFilter.allCases) { f in
                    MCChip(f.title, isActive: filter == f) { filter = f }
                        .accessibilityIdentifier("history-filter-\(f.rawValue)")
                }
            }
        }
    }

    /// Mock B `.heads-up { border-color:var(--orange) }` 段。橙色 panel + STUCK 脉冲指示
    /// + 内联列出 staleTasks 的每条卡(透明背景, dashed 分隔)。
    private var staleHeadsUp: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("— STALE AGENTS / \(formatted(staleTasks.count)) —")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(MissionControl.Color.orange)
                        .frame(width: 6, height: 6)
                        .shadow(color: MissionControl.Color.orange, radius: 4, x: 0, y: 0)
                    Text("STUCK")
                        .foregroundStyle(MissionControl.Color.orange)
                }
            }
            .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
            .tracking(1.8)
            .foregroundStyle(MissionControl.Color.inkSoft)

            VStack(spacing: 0) {
                ForEach(Array(staleTasks.enumerated()), id: \.element.id) { index, task in
                    staleTaskRow(task: task)
                        .padding(.vertical, 8)
                        .overlay(alignment: .top) {
                            if index > 0 {
                                Rectangle()
                                    .strokeBorder(
                                        MissionControl.Color.rule,
                                        style: StrokeStyle(lineWidth: 1, dash: [3])
                                    )
                                    .frame(height: 1)
                            }
                        }
                }
            }
        }
        .padding(14)
        .background(MissionControl.Color.hull)
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.orange, lineWidth: MissionControl.Border.hairline)
        )
    }

    private func staleTaskRow(task: AgentTask) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.displayName)
                    .font(MissionControl.Font.interTight(size: 14, weight: .heavy))
                    .tracking(-0.28)
                    .foregroundStyle(MissionControl.Color.ink)
                Text(staleCodeLine(for: task))
                    .font(MissionControl.Font.jetBrainsMono(size: 9.5, weight: .regular))
                    .tracking(0.4)
                    .foregroundStyle(MissionControl.Color.inkSoft)
            }
            Spacer(minLength: 8)
            MCBracketBadge(code: "[ STALE ]", color: MissionControl.Color.inkMute)
        }
    }

    private func staleCodeLine(for task: AgentTask) -> String {
        let elapsed = Int(-task.updatedAt.timeIntervalSinceNow / 60)
        let timeLabel: String
        if elapsed < 60 {
            timeLabel = "\(elapsed)m"
        } else if elapsed < 60 * 24 {
            let h = elapsed / 60
            let m = elapsed % 60
            timeLabel = m == 0 ? "\(h)h" : "\(h)h \(m)m"
        } else {
            timeLabel = "\(elapsed / (60 * 24))d"
        }
        var parts: [String] = ["last seen \(timeLabel) ago"]
        if let taskID = task.taskID { parts.append(taskID) }
        return parts.joined(separator: " · ")
    }

    private func formatted(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("— EMPTY TIMELINE —")
                .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(MissionControl.Color.inkSoft)
            Text("History fills in once tasks finish or pushes arrive.")
                .font(MissionControl.Font.jetBrainsMono(size: 11, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(MissionControl.Color.inkSoft)
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

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM · yyyy"
        return formatter.string(from: .now).uppercased()
    }

    private func itemsLabel(_ n: Int) -> String {
        n < 10 ? "0\(n) items" : "\(n) items"
    }
}

private enum HistoryFilter: String, Identifiable, CaseIterable {
    case all
    case archived
    case stale
    case incoming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .archived: return "Archived"
        case .stale: return "Stale"
        case .incoming: return "Incoming"
        }
    }

    func matches(_ item: HistoryItemData) -> Bool {
        switch self {
        case .all: return true
        case .archived: return item.kind == .agent
        case .stale: return item.kind == .stale
        case .incoming: return item.kind == .incoming
        }
    }
}
