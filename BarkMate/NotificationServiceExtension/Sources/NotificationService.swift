//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  Phase 2 管线(薄壳):
//    1. 通过 PushPipeline 跑 decrypt → parse → archive(失败降级 PendingQueue)
//    2. 把解密后的 alert 同步回 bestAttemptContent(让系统 banner 可读)
//    3. ImageEnricher 下载 image URL 作为 attachment
//    4. DarwinNotification.post 通知主 App 刷新
//    5. 任何阶段失败都不阻断 contentHandler
//

import UserNotifications
import SwiftData
import os
import Models
import Store
import BarkService

final class NotificationService: UNNotificationServiceExtension {

    private static let log = Logger(subsystem: "com.barkagent.ios", category: "nse")

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
            Self.log.error("SharedModelContainer.make failed: \(error.localizedDescription, privacy: .public)")
            container = nil
        }

        let cryptoBundle = container.flatMap { resolveCryptoBundle(container: $0) }
        let outcome = PushPipeline.process(
            userInfo: content.userInfo,
            bundle: cryptoBundle,
            container: container
        )

        applyDecrypted(content: content, from: outcome.decryptResult)
        applyAlertSound(content: content, from: outcome.decryptResult)
        await ImageEnricher().attachImageIfNeeded(userInfo: outcome.decryptResult.userInfo, to: content)

        switch outcome {
        case .archived, .pending:
            DarwinNotification.post(.itemDidArrive)
        case .dropped(_, _, let error):
            Self.log.error("push dropped (archive + pending both failed): \(error.localizedDescription, privacy: .public)")
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

    /// 把解密后的 alert 字段同步回通知内容,让系统也能展示明文 banner。
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

    /// 按用户 per-status 声音偏好覆写 content.sound。未配置则不动(保留发送方声音)。
    private func applyAlertSound(
        content: UNMutableNotificationContent,
        from result: DecryptProcessor.DecryptResult
    ) {
        switch AlertSoundResolver.decide(userInfo: result.userInfo) {
        case .keep:
            break
        case .silence:
            content.sound = nil
        case .named(let fileName):
            content.sound = UNNotificationSound(named: UNNotificationSoundName(fileName))
        }
    }
}
