//
//  SharedModelContainer.swift
//  Store
//

import Foundation
import SwiftData
import Models

/// 共享 ModelContainer 工厂。主应用与 Extensions 通过此工厂创建一致的 container。
public enum SharedModelContainer {

    /// 创建共享 ModelContainer。
    ///
    /// 所有 target 必须使用相同的 schema 和 store URL，否则会导致数据不一致。
    public static func make() throws -> ModelContainer {
        try AppGroup.ensureDirectories()
        return try make(storeURL: AppGroup.storeURL)
    }

    /// 在指定 URL 创建 ModelContainer。用于测试跨实例数据共享。
    public static func make(storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: currentSchema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: currentSchema,
            migrationPlan: BarkMateMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// 测试或预览用的内存 container。
    public static func makeInMemory() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: currentSchema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: currentSchema,
            configurations: [config]
        )
    }
}
