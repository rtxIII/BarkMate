//
//  AgentStep.swift
//  Models
//

import Foundation
import SwiftData

/// AgentTask 的单次推送快照。每次 Bark 推送都新增一条。
///
/// 通过 `AgentTask.steps` 反向关系访问，不建独立索引——
/// step 数量级远小于历史 Item 总量，通过 task 关系查询即可。
@Model
public final class AgentStep {
    @Attribute(.unique) public var id: UUID
    public var task: AgentTask?
    public var statusRaw: String
    public var title: String?
    public var body: String
    public var bodyTypeRaw: String
    public var progress: String?
    public var url: String?
    public var imageURL: String?
    /// 原始 Bark payload JSON（调试 / 摘要 prompt 用）。
    public var rawPayload: Data?
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Resource.step)
    public var resources: [Resource]

    public init(
        id: UUID = UUID(),
        task: AgentTask? = nil,
        status: AgentStatus,
        title: String? = nil,
        body: String,
        bodyType: BodyType = .plainText,
        progress: String? = nil,
        url: String? = nil,
        imageURL: String? = nil,
        rawPayload: Data? = nil,
        createdAt: Date = .now,
        resources: [Resource] = []
    ) {
        self.id = id
        self.task = task
        self.statusRaw = status.rawValue
        self.title = title
        self.body = body
        self.bodyTypeRaw = bodyType.rawValue
        self.progress = progress
        self.url = url
        self.imageURL = imageURL
        self.rawPayload = rawPayload
        self.createdAt = createdAt
        self.resources = resources
    }
}

extension AgentStep {
    public var status: AgentStatus {
        get { AgentStatus(rawValue: statusRaw) ?? .running }
        set { statusRaw = newValue.rawValue }
    }

    public var bodyType: BodyType {
        get { BodyType(rawValue: bodyTypeRaw) ?? .plainText }
        set { bodyTypeRaw = newValue.rawValue }
    }
}
