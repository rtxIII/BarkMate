//
//  LegacyItem.swift
//  Models
//
//  Temporary v0.2 compatibility model.
//  The v0.3 product direction uses AgentTask + AgentStep + Memo, but some
//  pre-migration app/package files still reference Item. Keeping this type
//  allows the mock UI work to compile while Phase 2 finishes the schema rewrite.
//

import Foundation
import SwiftData

public enum ItemType: String, Codable, Sendable, CaseIterable {
    case push
    case memo
}

@Model
public final class Item {
    @Attribute(.unique) public var id: UUID
    public var typeRaw: String
    public var title: String?
    public var subtitle: String?
    public var body: String
    public var bodyTypeRaw: String
    public var tags: [String]
    public var group: String?
    public var url: String?
    public var imageURL: String?
    public var metadata: Data?
    public var sourceServerID: UUID?
    public var isPinned: Bool
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    public var resources: [Resource]

    public init(
        id: UUID = UUID(),
        type: ItemType,
        title: String? = nil,
        subtitle: String? = nil,
        body: String,
        bodyType: BodyType = .plainText,
        tags: [String] = [],
        group: String? = nil,
        url: String? = nil,
        imageURL: String? = nil,
        metadata: Data? = nil,
        sourceServerID: UUID? = nil,
        isPinned: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        resources: [Resource] = []
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.bodyTypeRaw = bodyType.rawValue
        self.tags = tags
        self.group = group
        self.url = url
        self.imageURL = imageURL
        self.metadata = metadata
        self.sourceServerID = sourceServerID
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.resources = resources
    }
}

extension Item {
    public var type: ItemType {
        get { ItemType(rawValue: typeRaw) ?? .push }
        set { typeRaw = newValue.rawValue }
    }

    public var bodyType: BodyType {
        get { BodyType(rawValue: bodyTypeRaw) ?? .plainText }
        set { bodyTypeRaw = newValue.rawValue }
    }
}
