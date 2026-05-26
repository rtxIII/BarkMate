//
//  Container+App.swift
//  BarkMate
//
//  主 App 的 Factory 注册。每个进程（App / Extension）拥有独立的
//  Container.shared，需各自注册。
//

import Foundation
import Factory
import SwiftData
import Store
import BarkService

extension Container {

    /// 共享 SwiftData ModelContainer（App Group 存储）。
    var sharedModelContainer: Factory<ModelContainer> {
        self {
            do {
                return try SharedModelContainer.make()
            } catch {
                fatalError("Failed to create shared ModelContainer: \(error)")
            }
        }
        .singleton
    }

    /// Keychain 访问组配置。Team ID 从 Info.plist 动态读取。
    var keychainConfiguration: Factory<KeychainService.Configuration> {
        self {
            let teamID = Bundle.main.teamIdentifier ?? ""
            return .shared(teamID: teamID)
        }
        .singleton
    }

    /// APNs device token 存储（共享 UserDefaults）。
    var deviceTokenStore: Factory<DeviceTokenStore> {
        self { DeviceTokenStore() }
            .singleton
    }

    /// 通知 / APNs 健康状态(用于 Setup tab 顶部 banner)。
    var notificationStatusStore: Factory<NotificationStatusStore> {
        self { NotificationStatusStore() }
            .singleton
    }

    /// Bark 服务器 HTTP 客户端。
    var barkClient: Factory<BarkClientProtocol> {
        self { BarkClient() }
            .singleton
    }

    /// 推送注册协调器。
    var pushRegistrar: Factory<PushRegistrar> {
        self {
            PushRegistrar(
                modelContainer: Container.shared.sharedModelContainer(),
                barkClient: Container.shared.barkClient(),
                tokenStore: Container.shared.deviceTokenStore(),
                statusStore: Container.shared.notificationStatusStore()
            )
        }
        .singleton
    }

    /// Extension 降级队列消费者。
    var pendingQueueDrainer: Factory<PendingQueueDrainer> {
        self {
            PendingQueueDrainer(modelContainer: Container.shared.sharedModelContainer())
        }
        .singleton
    }
}

private extension Bundle {
    /// 从 Bundle 读取 App Identifier Prefix（TeamID + "."），去掉末尾点。
    var teamIdentifier: String? {
        guard let prefix = object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String else {
            return nil
        }
        return prefix.hasSuffix(".") ? String(prefix.dropLast()) : prefix
    }
}
