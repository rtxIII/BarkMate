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

/// 一个 project(agentID)下聚拢的若干 session 卡。
/// Dashboard 三段(Needs you / Running / Settled)按 `projectName` 分组后的产物:
///   - `cards.count == 1` → 视图层退化为原生单卡(不套折叠外壳)。
///   - `cards.count >= 2` → 视图层渲染 `MCProjectGroupCard`(可展开/折叠)。
///
/// `projectName` 即 `AgentCardData.agentName`(= displayName = agentID),
/// 见 push 落库路径 PushArchiver:同 agentID 的多次不同 session 推送按此聚拢。
public struct AgentProjectGroup: Identifiable, Equatable, Sendable {
    public let projectName: String
    /// 组内 session 卡,已按调用方的 prioritySort 排好序(最紧急在前)。
    public let cards: [AgentCardData]

    public init(projectName: String, cards: [AgentCardData]) {
        self.projectName = projectName
        self.cards = cards
    }

    /// SwiftUI ForEach 稳定标识。project 名在同一段内唯一。
    public var id: String { projectName }

    /// 是否需要折叠外壳(多 session 才折叠;单 session 退化原生卡)。
    public var isCollapsible: Bool { cards.count >= 2 }

    /// 组的代表卡(排序后第一张 = 最紧急),折叠态摘要与组排序位都以它为准。
    public var leadCard: AgentCardData? { cards.first }
}

extension AgentCardData {
    /// session 短码。原始 `taskID` 在真机 Claude Code 场景是裸 UUID(如
    /// `7326f398-b555-428a-a0d4-9d29c44896c4`),整串显示是纯噪声。这里收敛为:
    ///   - 形如 UUID → `#7326f398`(取首段 8 位)。
    ///   - 其它可读 taskID(如 `auth-migration`) → 原样返回。
    ///   - taskID 缺失 → nil(视图层据此隐藏该列)。
    public var sessionCode: String? {
        guard let taskID, !taskID.isEmpty else { return nil }
        if UUID(uuidString: taskID) != nil {
            let head = taskID.split(separator: "-").first.map(String.init) ?? taskID
            return "#\(head)"
        }
        return taskID
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
