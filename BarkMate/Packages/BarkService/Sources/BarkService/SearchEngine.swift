//
//  SearchEngine.swift
//  BarkService
//
//  内存级搜索引擎。SwiftData `#Predicate` 对 [String] contains-any-of 支持有限，
//  V1 直接拉所有未归档 Item 在内存中过滤；10k 量级下足够（plan.md 里 50fps 滚动假设）。
//

import Foundation
import Models

public struct SearchQuery: Equatable, Sendable {
    public var text: String
    public var types: Set<ItemType>
    public var tags: Set<String>
    public var groups: Set<String>
    public var dateRange: ClosedRange<Date>?

    public init(
        text: String = "",
        types: Set<ItemType> = [],
        tags: Set<String> = [],
        groups: Set<String> = [],
        dateRange: ClosedRange<Date>? = nil
    ) {
        self.text = text
        self.types = types
        self.tags = tags
        self.groups = groups
        self.dateRange = dateRange
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty &&
            types.isEmpty &&
            tags.isEmpty &&
            groups.isEmpty &&
            dateRange == nil
    }
}

public enum SearchEngine {

    /// 对 items 应用 query。query 全空时返回原序。
    public static func filter(_ items: [Item], query: SearchQuery) -> [Item] {
        guard !query.isEmpty else { return items }

        let trimmed = query.text.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            if !query.types.isEmpty, !query.types.contains(item.type) { return false }

            if let range = query.dateRange, !range.contains(item.createdAt) { return false }

            if !query.tags.isEmpty {
                let itemTags = Set(item.tags)
                if itemTags.isDisjoint(with: query.tags) { return false }
            }

            if !query.groups.isEmpty {
                guard let group = item.group, query.groups.contains(group) else { return false }
            }

            if !trimmed.isEmpty {
                if !textMatches(item: item, search: trimmed) { return false }
            }

            return true
        }
    }

    /// 提取所有 items 中出现过的 tag / group，供过滤 UI 显示 chip。
    public static func availableFacets(_ items: [Item]) -> Facets {
        var tagCounts: [String: Int] = [:]
        var groupCounts: [String: Int] = [:]
        for item in items {
            for tag in item.tags { tagCounts[tag, default: 0] += 1 }
            if let group = item.group, !group.isEmpty {
                groupCounts[group, default: 0] += 1
            }
        }
        return Facets(
            tags: tagCounts.sorted { $0.value > $1.value }.map(\.key),
            groups: groupCounts.sorted { $0.value > $1.value }.map(\.key)
        )
    }

    public struct Facets: Sendable, Equatable {
        public let tags: [String]
        public let groups: [String]
    }

    // MARK: - Internals

    private static func textMatches(item: Item, search: String) -> Bool {
        if let title = item.title, title.localizedStandardContains(search) { return true }
        if let subtitle = item.subtitle, subtitle.localizedStandardContains(search) { return true }
        if item.body.localizedStandardContains(search) { return true }
        if let group = item.group, group.localizedStandardContains(search) { return true }
        if item.tags.contains(where: { $0.localizedStandardContains(search) }) { return true }
        return false
    }
}
