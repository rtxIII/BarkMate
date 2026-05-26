//
//  HistoryView.swift
//  BarkMate
//
//  V0.3 Phase 3.4 History tab。归档 task + memo + 旧 Bark incoming 推送的回溯入口。
//  HistoryHero(深色) + chip 过滤 + 全量 HistoryRow。
//

import SwiftUI
import SwiftData
import Models
import DesignSystem

struct HistoryView: View {

    @Query(sort: \AgentTask.updatedAt, order: .reverse)
    private var tasks: [AgentTask]

    @Query(sort: \Memo.createdAt, order: .reverse)
    private var memos: [Memo]

    @State private var filter: HistoryFilter = .all

    private var items: [HistoryItemData] {
        let archivedTasks = tasks
            .filter { $0.status.isTerminal || $0.isArchived }
            .map(HistoryItemData.fromTask)
        let allMemos = memos.map(HistoryItemData.fromMemo)
        let merged = (archivedTasks + allMemos)
            .filter(filter.matches)
            .sorted { $0.updatedAt > $1.updatedAt }
        return merged
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HistoryHero()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HistoryFilter.allCases) { f in
                            Button(f.title) { filter = f }
                                .buttonStyle(ChipButtonStyle(isSelected: filter == f))
                        }
                    }
                }

                if items.isEmpty {
                    Text("History will appear once tasks finish or memos arrive.")
                        .font(.subheadline)
                        .foregroundStyle(BarkTheme.Palette.ink.opacity(0.58))
                        .mockCardPadding()
                } else {
                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            HistoryRow(data: item)
                        }
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .background(MockScreenBackground())
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    MemoEditorView()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New memo")
            }
        }
    }
}

private struct HistoryHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Pill("timeline", dark: true)
            Text("Messages become context, not noise.")
                .font(BarkTheme.Typography.heroSerif(size: 34))
                .tracking(-2)
                .foregroundStyle(.white)
            Text("旧协议推送、归档 task 和 memo 都在这里追溯。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.66))
        }
        .padding(18)
        .heroBackground(decorationColor: BarkTheme.Palette.infoCyan.opacity(0.30))
    }
}

private enum HistoryFilter: String, Identifiable, CaseIterable {
    case all
    case agents
    case incoming
    case memos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .agents: return "Archived agents"
        case .incoming: return "Incoming"
        case .memos: return "Memos"
        }
    }

    func matches(_ item: HistoryItemData) -> Bool {
        switch self {
        case .all: return true
        case .agents: return item.kind == .agent
        case .incoming: return item.kind == .incoming
        case .memos: return item.kind == .memo
        }
    }
}
