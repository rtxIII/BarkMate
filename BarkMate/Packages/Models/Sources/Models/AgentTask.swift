//
//  AgentTask.swift
//  Models
//

import Foundation
import SwiftData

/// Agent 持久卡片 —— Dashboard 上的状态机一等公民。
///
/// 聚合维度：`aggregateKey = "<agentID>::<taskID-or-_>"`。
/// 同一推送源（agent_id + task_id）的多次推送 → upsert 同一条 AgentTask，
/// 每次推送插入一条 AgentStep 作为历史记录。
@Model
public final class AgentTask {
    #Index<AgentTask>(
        [\.aggregateKey],
        [\.isArchived, \.updatedAt],
        [\.statusRaw, \.updatedAt],
        [\.isPinned, \.updatedAt]
    )

    @Attribute(.unique) public var id: UUID
    /// 聚合自然键。upsert 主路径。
    @Attribute(.unique) public var aggregateKey: String
    public var agentID: String
    public var taskID: String?
    public var displayName: String
    public var iconURL: String?
    public var statusRaw: String
    public var latestStepTitle: String?
    public var progress: String?
    public var eta: Date?
    public var isPinned: Bool
    public var isArchived: Bool
    public var isMuted: Bool
    public var sourceServerID: UUID?
    /// 关联的 ActivityKit Activity ID（若已启动 Live Activity）。
    public var liveActivityID: String?
    /// 设备端 LLM 摘要缓存（Phase 6 接入）。
    public var lastSummary: String?
    public var lastSummaryAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AgentStep.task)
    public var steps: [AgentStep]

    public init(
        id: UUID = UUID(),
        aggregateKey: String,
        agentID: String,
        taskID: String? = nil,
        displayName: String,
        iconURL: String? = nil,
        status: AgentStatus = .running,
        latestStepTitle: String? = nil,
        progress: String? = nil,
        eta: Date? = nil,
        isPinned: Bool = false,
        isArchived: Bool = false,
        isMuted: Bool = false,
        sourceServerID: UUID? = nil,
        liveActivityID: String? = nil,
        lastSummary: String? = nil,
        lastSummaryAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        steps: [AgentStep] = []
    ) {
        self.id = id
        self.aggregateKey = aggregateKey
        self.agentID = agentID
        self.taskID = taskID
        self.displayName = displayName
        self.iconURL = iconURL
        self.statusRaw = status.rawValue
        self.latestStepTitle = latestStepTitle
        self.progress = progress
        self.eta = eta
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.isMuted = isMuted
        self.sourceServerID = sourceServerID
        self.liveActivityID = liveActivityID
        self.lastSummary = lastSummary
        self.lastSummaryAt = lastSummaryAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.steps = steps
    }
}

extension AgentTask {
    public var status: AgentStatus {
        get { AgentStatus(rawValue: statusRaw) ?? .running }
        set { statusRaw = newValue.rawValue }
    }

    /// taskID 为 nil 时用 `_` 占位，保证 aggregateKey 总是唯一可查。
    public static func aggregateKey(agentID: String, taskID: String?) -> String {
        "\(agentID)::\(taskID ?? "_")"
    }
}
