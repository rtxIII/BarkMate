//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  Phase 2 管线：
//    1. DecryptProcessor → 处理 ciphertext（无配置/失败走降级）
//    2. 同步明文到 bestAttemptContent（让系统 banner 可读）
//    3. ImageEnricher → 下载 image URL 作为 UNNotificationAttachment
//    4. PushParser + PushArchiver → 入库；失败走 PendingQueue 旁路
//    5. DarwinNotification.post 通知主 App 刷新 / 消费 pending
//    6. 透传系统通知（任何失败都不阻断）
//

import UserNotifications
import SwiftData
import Models
import Store
import BarkService

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        let content = bestAttemptContent ?? UNMutableNotificationContent()

        Task {
            await self.processPipeline(content: content)
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func processPipeline(content: UNMutableNotificationContent) async {
        let container: ModelContainer?
        do {
            container = try SharedModelContainer.make()
        } catch {
            NSLog("[BarkMate] SharedModelContainer.make failed: \(error.localizedDescription)")
            container = nil
        }

        let cryptoBundle = container.flatMap { resolveCryptoBundle(container: $0) }
        let decryptResult = DecryptProcessor.decryptIfNeeded(
            userInfo: content.userInfo,
            bundle: cryptoBundle
        )
        applyDecrypted(content: content, from: decryptResult)

        await ImageEnricher().attachImageIfNeeded(userInfo: decryptResult.userInfo, to: content)

        let parsed = PushParser.parse(userInfo: decryptResult.userInfo)
        persist(parsed: parsed, degradation: decryptResult, container: container)
    }

    /// 优先写 SwiftData；失败 / 无 container 则落 PendingQueue。
    private func persist(
        parsed: ParsedPush,
        degradation: DecryptProcessor.DecryptResult,
        container: ModelContainer?
    ) {
        if let container {
            do {
                let archiver = PushArchiver(modelContainer: container)
                try archiver.archive(parsed, degradation: degradation)
                DarwinNotification.post(.itemDidArrive)
                return
            } catch {
                NSLog("[BarkMate] archive failed, falling back to PendingQueue: \(error.localizedDescription)")
            }
        }

        do {
            try PendingQueue().enqueue(parsed)
            DarwinNotification.post(.itemDidArrive)
        } catch {
            NSLog("[BarkMate] PendingQueue enqueue failed: \(error.localizedDescription)")
        }
    }

    private func resolveCryptoBundle(container: ModelContainer) -> CryptoBundle? {
        guard
            let prefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String
        else {
            return nil
        }
        let teamID = prefix.hasSuffix(".") ? String(prefix.dropLast()) : prefix
        let keychainConfig = KeychainService.Configuration.shared(teamID: teamID)
        let store = CryptoSettingsStore(modelContainer: container, keychainConfig: keychainConfig)
        return try? store.currentBundle()
    }

    /// 把解密后的 alert 字段同步回通知内容，让系统也能展示明文 banner。
    private func applyDecrypted(
        content: UNMutableNotificationContent,
        from result: DecryptProcessor.DecryptResult
    ) {
        guard
            let aps = result.userInfo["aps"] as? [String: Any],
            let alert = aps["alert"] as? [String: Any]
        else { return }

        if let title = alert["title"] as? String { content.title = title }
        if let subtitle = alert["subtitle"] as? String { content.subtitle = subtitle }
        if let body = alert["body"] as? String { content.body = body }
        content.userInfo = result.userInfo
    }
}
