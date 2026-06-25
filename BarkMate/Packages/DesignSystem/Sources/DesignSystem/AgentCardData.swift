//
//  AgentCardData.swift
//  DesignSystem
//
//  Dashboard / History / Detail 视图层的 view-model。
//  设计目的:
//    - 把 SwiftData 模型映射成轻量值类型,避免 @Model 引用语义引起的频繁重渲染。
//    - 卡片组件只依赖此结构体,可独立预览和单元测试。
//

import Foundation
import Models

public struct AgentCardData: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let agentName: String
    public let taskID: String?
    public let status: AgentStatus
    public let latestStep: String
    public let progressLabel: String?
    public let progressFraction: Double?
    public let etaLabel: String?
    public let updatedLabel: String
    public let isPinned: Bool
    public let isMuted: Bool

    public init(
        id: UUID,
        agentName: String,
        taskID: String?,
        status: AgentStatus,
        latestStep: String,
        progressLabel: String?,
        progressFraction: Double?,
        etaLabel: String?,
        updatedLabel: String,
        isPinned: Bool,
        isMuted: Bool
    ) {
        self.id = id
        self.agentName = agentName
        self.taskID = taskID
        self.status = status
        self.latestStep = latestStep
        self.progressLabel = progressLabel
        self.progressFraction = progressFraction
        self.etaLabel = etaLabel
        self.updatedLabel = updatedLabel
        self.isPinned = isPinned
        self.isMuted = isMuted
    }
}

public struct StepRowData: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timeLabel: String
    public let status: AgentStatus
    public let title: String
    public let body: String

    public init(
        id: UUID,
        timeLabel: String,
        status: AgentStatus,
        title: String,
        body: String
    ) {
        self.id = id
        self.timeLabel = timeLabel
        self.status = status
        self.title = title
        self.body = body
    }
}

public enum HistoryItemKind: String, Sendable, Equatable {
    case agent
    case incoming
    case stale
}

public struct HistoryItemData: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: HistoryItemKind
    public let kindBadge: String
    public let title: String
    public let body: String
    public let updatedAt: Date

    public init(
        id: UUID,
        kind: HistoryItemKind,
        kindBadge: String,
        title: String,
        body: String,
        updatedAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.kindBadge = kindBadge
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
    }
}

public enum SummaryPanelState: Equatable, Sendable {
    case ready
    case loading
    case generated(text: String, cacheLabel: String?)
}
