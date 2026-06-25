//
//  SchemaV1.swift
//  Models
//
//  BarkAgent SwiftData schema 版本管理。
//  V1 = 状态机中心设计（v0.4.0）：AgentTask + AgentStep + AgentInboxItem + Resource + Server + CryptoConfig。
//
//  应用尚未发布，无用户数据需迁移，故直接以当前模型作为 V1 schema。
//  Memo → AgentInboxItem 的改名也在 V1 内完成（mock B 删除了 user-memo 概念）。
//  后续 V2 扩展时新增 SchemaV2 并添加迁移 stage。
//

import Foundation
import SwiftData

public enum BarkAgentSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            AgentTask.self,
            AgentStep.self,
            AgentInboxItem.self,
            Resource.self,
            Server.self,
            CryptoConfig.self
        ]
    }
}

public enum BarkAgentMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [BarkAgentSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}

/// 便捷引用：当前 schema 版本。
/// 写成 computed property 兼容 Swift 6 strict concurrency 在 SwiftData.Schema 不
/// 为 Sendable 的旧 SDK（Xcode 16）下的全局存储检查。
public var currentSchema: Schema { Schema(versionedSchema: BarkAgentSchemaV1.self) }
