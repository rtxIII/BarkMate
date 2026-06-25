//
//  AgentInboxItem.swift
//  Models
//
//  旧 Bark 协议推送（无 agent_status 字段）的落盘点。
//  对应 mock B 的 History → Incoming 段，徽章 [ BARK ]。
//
//  从原 Memo 改名而来：删除 source 字段（永远是 incoming）、删除
//  tags 与 manual user-note 功能（mock B 已下线 memo 概念）。
//

import Foundation
import SwiftData

@Model
public final class AgentInboxItem {
    #Index<AgentInboxItem>(
        [\.createdAt],
        [\.isArchived, \.createdAt],
        [\.group, \.createdAt]
    )

    @Attribute(.unique) public var id: UUID
    public var title: String?
    public var body: String
    public var bodyTypeRaw: String
    /// Bark `group` 字段。
    public var group: String?
    /// 来源服务器；用于多 server 场景的归属过滤。
    public var sourceServerID: UUID?
    public var url: String?
    public var imageURL: String?
    public var isPinned: Bool
    public var isArchived: Bool
    /// 预留扩展 JSON blob（如解密失败时存原始密文）。
    public var metadata: Data?
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Resource.inboxItem)
    public var resources: [Resource]

    public init(
        id: UUID = UUID(),
        title: String? = nil,
        body: String,
        bodyType: BodyType = .plainText,
        group: String? = nil,
        sourceServerID: UUID? = nil,
        url: String? = nil,
        imageURL: String? = nil,
        isPinned: Bool = false,
        isArchived: Bool = false,
        metadata: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        resources: [Resource] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.bodyTypeRaw = bodyType.rawValue
        self.group = group
        self.sourceServerID = sourceServerID
        self.url = url
        self.imageURL = imageURL
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.resources = resources
    }
}

extension AgentInboxItem {
    public var bodyType: BodyType {
        get { BodyType(rawValue: bodyTypeRaw) ?? .plainText }
        set { bodyTypeRaw = newValue.rawValue }
    }
}
