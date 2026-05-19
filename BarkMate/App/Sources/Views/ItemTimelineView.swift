//
//  ItemTimelineView.swift
//  BarkMate
//
//  Phase 3: 日期分组 + ItemCard + swipe (archive/pin) + 浮动 + button + 下拉刷新。
//

import SwiftUI
import SwiftData
import Factory
import Models
import Store
import BarkService
import DesignSystem

struct ItemTimelineView: View {

    @State private var refreshToken: Int = 0
    @State private var darwinObserver: DarwinObserver?
    @State private var showingEditor: Bool = false

    @Injected(\.pendingQueueDrainer) private var pendingQueueDrainer: PendingQueueDrainer

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TimelineContentView(onRefresh: { await pendingQueueDrainer.drain() })
                .id(refreshToken)

            Button {
                showingEditor = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor, in: Circle())
                    .shadow(radius: 4, y: 2)
            }
            .padding(BarkTheme.Spacing.lg)
            .accessibilityLabel("New memo")
        }
        .navigationTitle("Timeline")
        .fullScreenCover(isPresented: $showingEditor) {
            MemoEditorView()
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
}

// MARK: - Content

private struct TimelineContentView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<Item> { $0.isArchived == false },
        sort: \Item.createdAt,
        order: .reverse
    )
    private var items: [Item]

    let onRefresh: @Sendable () async -> Void

    var body: some View {
        if items.isEmpty {
            EmptyTimelineState()
        } else {
            timelineList
        }
    }

    private var timelineList: some View {
        List {
            ForEach(groupedItems, id: \.headerKey) { group in
                groupSection(group)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .refreshable { await onRefresh() }
    }

    private func groupSection(_ group: TimelineGroup) -> some View {
        Section {
            ForEach(group.items) { item in
                itemRow(item)
            }
        } header: {
            Text(group.headerLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    private func itemRow(_ item: Item) -> some View {
        ItemCard(item: item)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(
                top: BarkTheme.Spacing.xs,
                leading: BarkTheme.Spacing.lg,
                bottom: BarkTheme.Spacing.xs,
                trailing: BarkTheme.Spacing.lg
            ))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    archive(item)
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    togglePin(item)
                } label: {
                    Label(
                        item.isPinned ? "Unpin" : "Pin",
                        systemImage: item.isPinned ? "pin.slash" : "pin"
                    )
                }
                .tint(.orange)
            }
    }

    // MARK: - Grouping / mutations

    private var groupedItems: [TimelineGroup] {
        let calendar = Calendar.current
        // 置顶项永远归到"Pinned"组
        let pinned = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }

        let dict = Dictionary(grouping: unpinned) { item in
            calendar.startOfDay(for: item.createdAt)
        }
        var groups = dict
            .map { TimelineGroup(kind: .date($0.key), items: $0.value) }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        if !pinned.isEmpty {
            groups.insert(TimelineGroup(kind: .pinned, items: pinned), at: 0)
        }
        return groups
    }

    private func archive(_ item: Item) {
        item.isArchived = true
        item.updatedAt = .now
        try? modelContext.save()
    }

    private func togglePin(_ item: Item) {
        item.isPinned.toggle()
        item.updatedAt = .now
        try? modelContext.save()
    }
}

// MARK: - Helpers

private struct TimelineGroup {
    enum Kind {
        case pinned
        case date(Date)
    }

    let kind: Kind
    let items: [Item]

    var date: Date? {
        if case .date(let value) = kind { return value }
        return nil
    }

    var headerKey: String {
        switch kind {
        case .pinned: return "__pinned__"
        case .date(let date): return "\(date.timeIntervalSince1970)"
        }
    }

    var headerLabel: String {
        switch kind {
        case .pinned:
            return "Pinned"
        case .date(let date):
            let calendar = Calendar.current
            if calendar.isDateInToday(date) { return "Today" }
            if calendar.isDateInYesterday(date) { return "Yesterday" }
            let formatter = DateFormatter()
            if calendar.isDate(date, equalTo: .now, toGranularity: .weekOfYear) {
                formatter.setLocalizedDateFormatFromTemplate("EEEE")
            } else if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
                formatter.setLocalizedDateFormatFromTemplate("MMMd")
            } else {
                formatter.setLocalizedDateFormatFromTemplate("yMMMd")
            }
            return formatter.string(from: date)
        }
    }
}

private struct EmptyTimelineState: View {
    var body: some View {
        ContentUnavailableView {
            Label("BarkMate", systemImage: "tray.full")
        } description: {
            Text("Timeline is empty.\nSend a push or tap + to add a memo.")
                .multilineTextAlignment(.center)
        }
    }
}
