//
//  SchemaV1.swift
//  Models
//
//  BarkMate SwiftData schema 版本管理。
//  V1 = 状态机中心设计（v0.3.0）：AgentTask + AgentStep + Memo + Resource + Server + CryptoConfig。
//
//  应用尚未发布，无用户数据需迁移，故直接以 v0.3 模型作为 V1 schema。
//  后续 V2 扩展时新增 SchemaV2 并添加迁移 stage。
//

import Foundation
import SwiftData

public enum BarkMateSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            AgentTask.self,
            AgentStep.self,
            Memo.self,
            Resource.self,
            Server.self,
            CryptoConfig.self
        ]
    }
}

public enum BarkMateMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [BarkMateSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}

/// 便捷引用：当前 schema 版本。
public let currentSchema: Schema = Schema(versionedSchema: BarkMateSchemaV1.self)
