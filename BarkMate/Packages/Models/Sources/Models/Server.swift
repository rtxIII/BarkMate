//
//  Server.swift
//  Models
//

import Foundation
import SwiftData

/// Bark 服务器配置。
@Model
public final class Server {
    #Index<Server>([\.address])

    @Attribute(.unique) public var id: UUID
    public var name: String?
    public var address: String
    public var key: String
    public var stateRaw: String
    public var lastSyncedAt: Date?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        address: String,
        key: String,
        state: ServerState = .ok,
        lastSyncedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.key = key
        self.stateRaw = state.rawValue
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
    }
}

extension Server {
    public var state: ServerState {
        get { ServerState(rawValue: stateRaw) ?? .ok }
        set { stateRaw = newValue.rawValue }
    }
}
