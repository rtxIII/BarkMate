//
//  SearchEngine.swift
//  BarkService
//
//  三表联合搜索（AgentTask / AgentStep / AgentInboxItem）。
//
//  SwiftData `#Predicate` 不支持 `localizedStandardContains`（中文 / 大小写不敏感），
//  因此采用混合方案：用 ModelContext.fetch 取出记录后，在内存做文本 / 标签匹配。
//  V1 在 10k 量级下足够（plan.md §4.7 query < 300ms）；超 50k 走 V2 FTS5。
//

import Foundation
import SwiftData
import Models

/// 搜索作用的数据源范围。OptionSet 支持组合（如 `[.agents, .inbox]`）。
public struct SearchScope: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let agents = SearchScope(rawValue: 1 << 0)
    public static let steps  = SearchScope(rawValue: 1 << 1)
    public static let inbox  = SearchScope(rawValue: 1 << 2)
    public static let all: SearchScope = [.agents, .steps, .inbox]
}

public struct SearchQuery: Equatable, Sendable {
    public var text: String
    public var scope: SearchScope
    /// 作用于 AgentTask.agentID 与 AgentInboxItem.group。
    public var agentIDs: Set<String>
    /// 作用于 AgentTask.status 与 AgentStep.status。非空时 inbox 自动排除（无 status 字段）。
    public var statuses: Set<AgentStatus>
    /// 基于 `SearchResult.updatedAt` 过滤。
    public var dateRange: ClosedRange<Date>?
    public var includeArchived: Bool

    public init(
        text: String = "",
        scope: SearchScope = .all,
        agentIDs: Set<String> = [],
        statuses: Set<AgentStatus> = [],
        dateRange: ClosedRange<Date>? = nil,
        includeArchived: Bool = false
    ) {
        self.text = text
        self.scope = scope
        self.agentIDs = agentIDs
        self.statuses = statuses
        self.dateRange = dateRange
        self.includeArchived = includeArchived
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty &&
            agentIDs.isEmpty &&
            statuses.isEmpty &&
            dateRange == nil
    }
}

/// 统一包装三表结果，便于合并排序。
///
/// 注意：底层是 SwiftData `@Model` 引用类型，仅在 fetch 所在 ModelContext 的线程内有效，
/// 不应跨线程传递，故不实现 `Sendable`。`Equatable` 基于 `id` 比较，足以满足测试断言。
public enum SearchResult: Equatable {
    case agent(AgentTask)
    case step(AgentStep)
    case inbox(AgentInboxItem)

    public var updatedAt: Date {
        switch self {
        case .agent(let task): return task.updatedAt
        case .step(let step): return step.createdAt
        case .inbox(let item): return item.updatedAt
        }
    }

    public var id: UUID {
        switch self {
        case .agent(let task): return task.id
        case .step(let step): return step.id
        case .inbox(let item): return item.id
        }
    }

    public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        switch (lhs, rhs) {
        case (.agent(let l), .agent(let r)): return l.id == r.id
        case (.step(let l), .step(let r)): return l.id == r.id
        case (.inbox(let l), .inbox(let r)): return l.id == r.id
        default: return false
        }
    }
}

public enum SearchEngine {

    /// 主入口：按 scope 分别 fetch 三表，内存过滤后按 updatedAt DESC 合并，截断到 limit。
    ///
    /// 去重：同一 AgentTask 若被 agent 命中，则其 step 结果被丢弃（避免重复展示）。
    public static func search(
        _ query: SearchQuery,
        in context: ModelContext,
        limit: Int = 200
    ) throws -> [SearchResult] {
        let trimmed = query.text.trimmingCharacters(in: .whitespaces)
        var results: [SearchResult] = []
        var matchedTaskIDs: Set<UUID> = []

        if query.scope.contains(.agents) {
            let tasks = try context.fetch(FetchDescriptor<AgentTask>())
            for task in tasks where matches(task, query: query, text: trimmed) {
                results.append(.agent(task))
                matchedTaskIDs.insert(task.id)
            }
        }

        // AgentInboxItem —— 无 status 概念,statuses 非空时排除。
        if query.scope.contains(.inbox), query.statuses.isEmpty {
            let items = try context.fetch(FetchDescriptor<AgentInboxItem>())
            for item in items where matches(item, query: query, text: trimmed) {
                results.append(.inbox(item))
            }
        }

        // AgentStep —— 去重所属已命中 task。
        if query.scope.contains(.steps) {
            let steps = try context.fetch(FetchDescriptor<AgentStep>())
            for step in steps where matches(step, query: query, text: trimmed) {
                if let taskID = step.task?.id, matchedTaskIDs.contains(taskID) { continue }
                results.append(.step(step))
            }
        }

        results.sort { $0.updatedAt > $1.updatedAt }
        return Array(results.prefix(limit))
    }

    /// 从全表提取 agentID 频次，供过滤 UI 显示 chip。
    public static func availableFacets(in context: ModelContext) throws -> Facets {
        var agentCounts: [String: Int] = [:]

        let items = try context.fetch(FetchDescriptor<AgentInboxItem>())
        for item in items {
            if let group = item.group, !group.isEmpty {
                agentCounts[group, default: 0] += 1
            }
        }

        let tasks = try context.fetch(FetchDescriptor<AgentTask>())
        for task in tasks where !task.agentID.isEmpty {
            agentCounts[task.agentID, default: 0] += 1
        }

        return Facets(
            agentIDs: agentCounts.sorted { $0.value > $1.value }.map(\.key)
        )
    }

    public struct Facets: Sendable, Equatable {
        public let agentIDs: [String]

        public init(agentIDs: [String]) {
            self.agentIDs = agentIDs
        }
    }

    // MARK: - Per-type matching

    private static func matches(_ task: AgentTask, query: SearchQuery, text: String) -> Bool {
        if !query.includeArchived, task.isArchived { return false }
        if let range = query.dateRange, !range.contains(task.updatedAt) { return false }
        if !query.agentIDs.isEmpty, !query.agentIDs.contains(task.agentID) { return false }
        if !query.statuses.isEmpty, !query.statuses.contains(task.status) { return false }
        guard !text.isEmpty else { return true }

        if task.displayName.localizedStandardContains(text) { return true }
        if task.agentID.localizedStandardContains(text) { return true }
        if let title = task.latestStepTitle, title.localizedStandardContains(text) { return true }
        if let taskID = task.taskID, taskID.localizedStandardContains(text) { return true }
        return false
    }

    private static func matches(_ step: AgentStep, query: SearchQuery, text: String) -> Bool {
        if !query.includeArchived, step.task?.isArchived == true { return false }
        if let range = query.dateRange, !range.contains(step.createdAt) { return false }
        if !query.agentIDs.isEmpty {
            guard let agentID = step.task?.agentID, query.agentIDs.contains(agentID) else { return false }
        }
        if !query.statuses.isEmpty, !query.statuses.contains(step.status) { return false }
        guard !text.isEmpty else { return true }

        if let title = step.title, title.localizedStandardContains(text) { return true }
        if step.body.localizedStandardContains(text) { return true }
        return false
    }

    private static func matches(_ item: AgentInboxItem, query: SearchQuery, text: String) -> Bool {
        if !query.includeArchived, item.isArchived { return false }
        if let range = query.dateRange, !range.contains(item.updatedAt) { return false }
        if !query.agentIDs.isEmpty {
            guard let group = item.group, query.agentIDs.contains(group) else { return false }
        }
        guard !text.isEmpty else { return true }

        if let title = item.title, title.localizedStandardContains(text) { return true }
        if item.body.localizedStandardContains(text) { return true }
        if let group = item.group, group.localizedStandardContains(text) { return true }
        return false
    }
}
