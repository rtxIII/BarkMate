//
//  SearchView.swift
//  BarkMate
//
//  Phase 4-Core 搜索：内存过滤 (SearchEngine) + 类型/标签/分组 chip 过滤 + 高亮。
//

import SwiftUI
import SwiftData
import Models
import BarkService
import DesignSystem

struct SearchView: View {

    @Query(
        filter: #Predicate<Item> { $0.isArchived == false },
        sort: \Item.createdAt,
        order: .reverse
    )
    private var items: [Item]

    @State private var queryText: String = ""
    @State private var selectedTypes: Set<ItemType> = []
    @State private var selectedTags: Set<String> = []
    @State private var selectedGroups: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if filteredItems.isEmpty {
                ContentUnavailableView(
                    "No results",
                    systemImage: "magnifyingglass",
                    description: Text(queryText.isEmpty ? "Try a keyword or filter." : "Nothing matched “\(queryText)”.")
                )
            } else {
                resultList
            }
        }
        .navigationTitle("Search")
        .searchable(text: $queryText, placement: .navigationBarDrawer(displayMode: .always))
    }

    // MARK: - Subviews

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BarkTheme.Spacing.sm) {
                Menu {
                    ForEach(ItemType.allCases, id: \.self) { type in
                        Button {
                            toggleType(type)
                        } label: {
                            Label(typeLabel(type), systemImage: selectedTypes.contains(type) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                } label: {
                    chipLabel("Type", count: selectedTypes.count)
                }

                if !facets.tags.isEmpty {
                    Menu {
                        ForEach(facets.tags, id: \.self) { tag in
                            Button {
                                toggleTag(tag)
                            } label: {
                                Label("#\(tag)", systemImage: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    } label: {
                        chipLabel("Tags", count: selectedTags.count)
                    }
                }

                if !facets.groups.isEmpty {
                    Menu {
                        ForEach(facets.groups, id: \.self) { group in
                            Button {
                                toggleGroup(group)
                            } label: {
                                Label(group, systemImage: selectedGroups.contains(group) ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    } label: {
                        chipLabel("Groups", count: selectedGroups.count)
                    }
                }

                if hasFilters {
                    Button("Clear", role: .destructive) {
                        selectedTypes.removeAll()
                        selectedTags.removeAll()
                        selectedGroups.removeAll()
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, BarkTheme.Spacing.lg)
            .padding(.vertical, BarkTheme.Spacing.sm)
        }
    }

    private var resultList: some View {
        List(filteredItems) { item in
            VStack(alignment: .leading, spacing: BarkTheme.Spacing.xs) {
                if let title = item.title, !title.isEmpty {
                    HighlightedText(title, highlight: queryText, lineLimit: 1)
                        .font(.headline)
                }
                HighlightedText(item.body, highlight: queryText, lineLimit: 2)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                metadataRow(for: item)
            }
            .padding(.vertical, BarkTheme.Spacing.xs)
        }
        .listStyle(.plain)
    }

    private func metadataRow(for item: Item) -> some View {
        HStack(spacing: BarkTheme.Spacing.xs) {
            Image(systemName: item.type == .push ? "bell.badge" : "note.text")
                .font(.caption2)
                .foregroundStyle(.tint)
            ForEach(Array(item.tags.prefix(3)), id: \.self) { tag in
                TagChip(tag)
            }
            if let group = item.group, !group.isEmpty {
                TagChip(group, style: .group)
            }
            Spacer()
            Text(item.createdAt, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private var query: SearchQuery {
        SearchQuery(
            text: queryText,
            types: selectedTypes,
            tags: selectedTags,
            groups: selectedGroups
        )
    }

    private var filteredItems: [Item] {
        SearchEngine.filter(items, query: query)
    }

    private var facets: SearchEngine.Facets {
        SearchEngine.availableFacets(items)
    }

    private var hasFilters: Bool {
        !selectedTypes.isEmpty || !selectedTags.isEmpty || !selectedGroups.isEmpty
    }

    private func toggleType(_ type: ItemType) {
        if selectedTypes.contains(type) { selectedTypes.remove(type) } else { selectedTypes.insert(type) }
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
    }

    private func toggleGroup(_ group: String) {
        if selectedGroups.contains(group) { selectedGroups.remove(group) } else { selectedGroups.insert(group) }
    }

    private func chipLabel(_ title: String, count: Int) -> some View {
        Text(count > 0 ? "\(title) (\(count))" : title)
            .font(.caption)
            .padding(.horizontal, BarkTheme.Spacing.md)
            .padding(.vertical, BarkTheme.Spacing.xs)
            .background(
                count > 0 ? BarkTheme.Palette.groupPill : BarkTheme.Palette.chipBackground,
                in: Capsule()
            )
            .foregroundStyle(count > 0 ? Color.accentColor : Color.primary)
    }

    private func typeLabel(_ type: ItemType) -> String {
        switch type {
        case .push: return "Push"
        case .memo: return "Memo"
        }
    }
}
