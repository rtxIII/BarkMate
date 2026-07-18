//
//  Container+App.swift
//  BarkAgent
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
    /// 优先用 App Group 共享 store。若失败（entitlement 异常 / Sandbox 同步延迟），
    /// 降级到 in-memory container 并把 `.storageUnavailable` 写到状态条，让 UI
    /// 显示明确指引而不是冷启动 crash。
    var sharedModelContainer: Factory<ModelContainer> {
        self {
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                ProcessInfo.processInfo.environment["BARKAGENT_UI_TESTING"] == "1" {
                do {
                    return try SharedModelContainer.makeInMemory()
                } catch {
                    fatalError("In-memory ModelContainer init failed during tests: \(error)")
                }
            }
            do {
                let modelContainer = try SharedModelContainer.make()
                let statusStore = NotificationStatusStore()
                if statusStore.current().kind == .storageUnavailable {
                    statusStore.save(.unknown)
                }
                return modelContainer
            } catch {
                BarkLog.storage.fault(
                    "shared container init failed, falling back to in-memory: \(error.localizedDescription, privacy: .public)"
                )
                NotificationStatusStore().save(
                    NotificationStatus(
                        kind: .storageUnavailable,
                        detail: "Shared storage unavailable: \(error.localizedDescription). Reinstall the app to recover."
                    )
                )
                do {
                    return try SharedModelContainer.makeInMemory()
                } catch {
                    // 内存 container 也无法构造说明 SwiftData runtime 自己出问题；
                    // 此时无路可走，保留 fatalError 让 crash 报告里有可读 stack。
                    fatalError("Both shared and in-memory ModelContainer init failed: \(error)")
                }
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
        self {
            let store = DeviceTokenStore(defaults: ProcessInfo.processInfo.barkAgentTestDefaults)
            if let token = ProcessInfo.processInfo.environment["BARKAGENT_UI_DEVICE_TOKEN"],
               ProcessInfo.processInfo.environment["BARKAGENT_UI_TESTING"] == "1" {
                store.save(token: token)
            }
            return store
        }
            .singleton
    }

    /// Per-status 声音偏好存储(共享 UserDefaults)。
    var alertSoundStore: Factory<AlertSoundStore> {
        self {
            AlertSoundStore(defaults: ProcessInfo.processInfo.barkAgentTestDefaults)
        }
        .singleton
    }

    /// Stale timeout 阈值存储(共享 UserDefaults)。
    var staleTimeoutStore: Factory<StaleTimeoutStore> {
        self {
            StaleTimeoutStore(defaults: ProcessInfo.processInfo.barkAgentTestDefaults)
        }
        .singleton
    }

    /// 通知 / APNs 健康状态(用于 Setup tab 顶部 banner)。
    var notificationStatusStore: Factory<NotificationStatusStore> {
        self {
            let store = NotificationStatusStore(defaults: ProcessInfo.processInfo.barkAgentTestDefaults)
            let env = ProcessInfo.processInfo.environment
            if env["BARKAGENT_UI_TESTING"] == "1",
               let rawKind = env["BARKAGENT_UI_NOTIFICATION_STATUS"],
               let kind = NotificationStatusKind(rawValue: rawKind) {
                store.save(NotificationStatus(
                    kind: kind,
                    detail: env["BARKAGENT_UI_NOTIFICATION_DETAIL"]
                ))
            }
            return store
        }
            .singleton
    }

    /// Bark 服务器 HTTP 客户端。
    var barkClient: Factory<BarkClientProtocol> {
        self {
            if let mode = ProcessInfo.processInfo.barkAgentUITestBarkClientMode {
                return UITestBarkClient(mode: mode)
            }
            return BarkClient()
        }
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
            let pendingQueueBaseDirectory: URL?
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                ProcessInfo.processInfo.environment["BARKAGENT_UI_TESTING"] == "1" {
                pendingQueueBaseDirectory = FileManager.default.temporaryDirectory
                    .appending(path: "BarkAgentTests/pending_messages", directoryHint: .isDirectory)
            } else {
                pendingQueueBaseDirectory = nil
            }
            return PendingQueueDrainer(
                modelContainer: Container.shared.sharedModelContainer(),
                pendingQueueBaseDirectory: pendingQueueBaseDirectory
            )
        }
        .singleton
    }
}

private extension ProcessInfo {
    var barkAgentTestDefaults: UserDefaults? {
        let env = environment
        guard env["XCTestConfigurationFilePath"] != nil || env["BARKAGENT_UI_TESTING"] == "1" else {
            return nil
        }
        let suiteName = env["BARKAGENT_TEST_DEFAULTS_SUITE"] ?? "BarkAgentTests"
        return UserDefaults(suiteName: suiteName)
    }

    var barkAgentUITestBarkClientMode: String? {
        let env = environment
        guard env["BARKAGENT_UI_TESTING"] == "1" else { return nil }
        return env["BARKAGENT_UI_BARK_CLIENT"]
    }
}

private struct UITestBarkClient: BarkClientProtocol {
    let mode: String

    func register(
        deviceToken: String,
        serverURL: URL,
        existingKey: String?
    ) async throws -> String {
        if mode == "failure" {
            throw BarkAPIError.httpStatus(503)
        }
        return existingKey ?? "ui-test-key"
    }

    func ping(serverURL: URL) async throws -> Bool {
        if mode == "failure" {
            throw BarkAPIError.httpStatus(503)
        }
        return true
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
