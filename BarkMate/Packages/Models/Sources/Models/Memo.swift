//
//  Memo.swift
//  Models
//

import Foundation
import SwiftData

/// 备忘录 —— 同时承载两种来源：
/// - `source == .manual`：用户手写 / Share Extension 写入
/// - `source == .incoming`：旧 Bark 协议推送（无 agent_status 字段）的降级落盘
@Model
public final class Memo {
    #Index<Memo>(
        [\.createdAt],
        [\.isArchived, \.createdAt],
        [\.sourceRaw, \.createdAt]
    )

    @Attribute(.unique) public var id: UUID
    public var sourceRaw: String
    public var title: String?
    public var body: String
    public var bodyTypeRaw: String
    public var tags: [String]
    /// 旧协议 incoming memo 的 Bark `group` 字段（manual memo 通常为 nil）。
    public var group: String?
    /// incoming memo 的来源服务器；manual 为 nil。
    public var sourceServerID: UUID?
    public var url: String?
    public var imageURL: String?
    public var isPinned: Bool
    public var isArchived: Bool
    /// 预留扩展 JSON blob。
    public var metadata: Data?
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Resource.memo)
    public var resources: [Resource]

    public init(
        id: UUID = UUID(),
        source: MemoSource,
        title: String? = nil,
        body: String,
        bodyType: BodyType = .plainText,
        tags: [String] = [],
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
        self.sourceRaw = source.rawValue
        self.title = title
        self.body = body
        self.bodyTypeRaw = bodyType.rawValue
        self.tags = tags
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

extension Memo {
    public var source: MemoSource {
        get { MemoSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    public var bodyType: BodyType {
        get { BodyType(rawValue: bodyTypeRaw) ?? .plainText }
        set { bodyTypeRaw = newValue.rawValue }
    }
}
