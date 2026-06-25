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

    private var items: [HistoryItemData] {
        let archivedTasks = tasks
            .filter { $0.status.isTerminal || $0.isArchived }
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
                }
            }
        }
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
    case incoming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .archived: return "Archived"
        case .incoming: return "Incoming"
        }
    }

    func matches(_ item: HistoryItemData) -> Bool {
        switch self {
        case .all: return true
        case .archived: return item.kind == .agent
        case .incoming: return item.kind == .incoming
        }
    }
}
