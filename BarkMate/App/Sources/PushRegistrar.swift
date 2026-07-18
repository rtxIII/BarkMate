//
//  PushRegistrar.swift
//  BarkAgent
//
//  APNs token → 自建服务器注册的协调层。
//  - 启动时若 SwiftData 中无 Server，注入默认 BarkAgent 服务器
//  - 收到 device token 后调 BarkClient.register，把服务器分配的 key 持久化到 Server
//

import Foundation
import SwiftData
import Models
import Store
import BarkService

@MainActor
final class PushRegistrar {

    static let defaultServerAddress = "https://barkagent.we2.xyz"
    static let defaultServerName = "BarkAgent Cloud"

    private let modelContainer: ModelContainer
    private let barkClient: BarkClientProtocol
    private let tokenStore: DeviceTokenStore
    private let statusStore: NotificationStatusStore

    nonisolated init(
        modelContainer: ModelContainer,
        barkClient: BarkClientProtocol,
        tokenStore: DeviceTokenStore,
        statusStore: NotificationStatusStore
    ) {
        self.modelContainer = modelContainer
        self.barkClient = barkClient
        self.tokenStore = tokenStore
        self.statusStore = statusStore
    }

    /// 启动时调用：若没有任何 Server 则插入默认服务器（key 留空、状态 pending）。
    func seedDefaultServerIfNeeded() {
        let context = modelContainer.mainContext
        let existing = (try? context.fetch(FetchDescriptor<Server>())) ?? []
        if !existing.isEmpty {
            dprint("[PushRegistrar] seed skipped — \(existing.count) server(s) already present")
            return
        }

        let server = Server(
            name: Self.defaultServerName,
            address: Self.defaultServerAddress,
            key: "",
            state: .pending
        )
        context.insert(server)
        do {
            try context.save()
            dprint("[PushRegistrar] seeded default server")
        } catch {
            BarkLog.storage.error("seed save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 收到 APNs token 后调用：保存 token + 对所有未注册（key 为空）的 server 调 register。
    func handleDeviceToken(_ token: String) async {
        tokenStore.save(token: token)
        dprint("[PushRegistrar] token saved to store (len=\(token.count))")

        let context = modelContainer.mainContext
        let servers: [Server]
        do {
            servers = try context.fetch(FetchDescriptor<Server>())
        } catch {
            BarkLog.storage.error("fetch servers failed: \(error.localizedDescription, privacy: .public)")
            saveNotificationStatusPreservingStorageFailure(NotificationStatus(
                kind: .serverUnreachable,
                detail: "Failed to enumerate servers: \(error.localizedDescription)"
            ))
            return
        }
        dprint("[PushRegistrar] registering with \(servers.count) server(s)")

        var anyFailed = false
        for server in servers {
            let success = await register(server: server, token: token, context: context)
            if !success { anyFailed = true }
        }
        if anyFailed {
            saveNotificationStatusPreservingStorageFailure(NotificationStatus(
                kind: .serverUnreachable,
                detail: "One or more servers failed to register. Open Servers to retry."
            ))
        } else if !servers.isEmpty {
            saveNotificationStatusPreservingStorageFailure(NotificationStatus(kind: .ok))
        }
    }

    private func saveNotificationStatusPreservingStorageFailure(_ status: NotificationStatus) {
        guard statusStore.current().kind != .storageUnavailable else { return }
        statusStore.save(status)
    }

    @discardableResult
    private func register(server: Server, token: String, context: ModelContext) async -> Bool {
        guard let url = URL(string: server.address) else {
            BarkLog.push.error("invalid server URL")
            server.state = .error
            try? context.save()
            return false
        }

        let existingKey: String? = server.key.isEmpty ? nil : server.key
        dprint("[PushRegistrar] → register existingKey=\(existingKey != nil ? "<set>" : "nil")")
        do {
            let assignedKey = try await barkClient.register(
                deviceToken: token,
                serverURL: url,
                existingKey: existingKey
            )
            server.key = assignedKey
            server.state = .ok
            server.lastSyncedAt = .now
            try context.save()
            BarkLog.push.info("registered with server (key len=\(assignedKey.count, privacy: .public))")
            return true
        } catch {
            server.state = .error
            try? context.save()
            BarkLog.push.error("register failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
