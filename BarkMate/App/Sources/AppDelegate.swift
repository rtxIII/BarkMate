//
//  AppDelegate.swift
//  BarkAgent
//
//  通过 @UIApplicationDelegateAdaptor 接入 SwiftUI 生命周期。
//  负责 APNs 注册流程：
//    1. 启动时确保有默认服务器
//    2. 请求通知权限 → registerForRemoteNotifications
//    3. 收到 device token 后调 PushRegistrar.handleDeviceToken
//

import UIKit
import UserNotifications
import Factory
import Store

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    @Injected(\.pushRegistrar) private var pushRegistrar: PushRegistrar
    @Injected(\.pendingQueueDrainer) private var pendingQueueDrainer: PendingQueueDrainer
    @Injected(\.notificationStatusStore) private var statusStore: NotificationStatusStore

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 前台通知呈现钩子:app 在前台时,只要有通知要展示,系统必定回调 willPresent。
        // 这是"前台收到推送"的可靠信号(比 NSE 的 Darwin 刷新信号更确定)。
        UNUserNotificationCenter.current().delegate = self
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            dprint("[BarkAgent] XCTest host launch, skipping app startup side effects")
            return true
        }
        #endif
        dprint("[BarkAgent] AppDelegate didFinishLaunching")
        Task { @MainActor in
            pushRegistrar.seedDefaultServerIfNeeded()
            dprint("[BarkAgent] seedDefaultServerIfNeeded done")
            pendingQueueDrainer.start()
            #if DEBUG
            // SIM_SKIP_NOTIF_PROMPT=1 时跳过通知权限弹窗,用于 UI 截图/快照测试。
            if ProcessInfo.processInfo.environment["SIM_SKIP_NOTIF_PROMPT"] == "1" {
                dprint("[BarkAgent] SIM_SKIP_NOTIF_PROMPT=1, skipping notification prompt")
                return
            }
            #endif
            await requestAuthorizationAndRegister(application: application)
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        #if DEBUG
        dprint("[BarkAgent] APNs device token received: \(hex.prefix(8))… (len=\(hex.count))")
        #else
        BarkLog.push.info("APNs token received (len=\(hex.count, privacy: .public))")
        #endif
        Task { @MainActor in
            await pushRegistrar.handleDeviceToken(hex)
            dprint("[BarkAgent] handleDeviceToken finished")
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        BarkLog.push.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
        saveNotificationStatusPreservingStorageFailure(NotificationStatus(
            kind: .apnsRegistrationFailed,
            detail: error.localizedDescription
        ))
    }

    // MARK: - 前台推送呈现

    /// app 在前台收到推送:返回 `.sound`(保留推送声)+ `.list`(留在通知中心),
    /// 但不含 `.banner` —— 前台不弹系统横幅。同时广播应内事件,由 MainTabView 弹 toast。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let message = content.title.isEmpty ? content.body : content.title
        NotificationCenter.default.post(
            name: Self.foregroundPushDidArrive,
            object: nil,
            userInfo: message.isEmpty ? nil : [Self.foregroundPushMessageKey: message]
        )
        completionHandler([.sound, .list])
    }

    /// 前台收到推送的应内事件。userInfo[foregroundPushMessageKey] 为可选标题文案。
    static let foregroundPushDidArrive = Notification.Name("com.barkagent.foregroundPushDidArrive")
    static let foregroundPushMessageKey = "message"

    @MainActor
    private func requestAuthorizationAndRegister(application: UIApplication) async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            dprint("[BarkAgent] Notification authorization granted=\(granted)")
            if granted {
                application.registerForRemoteNotifications()
                dprint("[BarkAgent] registerForRemoteNotifications called, waiting for callback…")
            } else {
                saveNotificationStatusPreservingStorageFailure(NotificationStatus(
                    kind: .authorizationDenied,
                    detail: "Notification permission was denied"
                ))
            }
        } catch {
            BarkLog.push.error("Notification authorization error: \(error.localizedDescription, privacy: .public)")
            saveNotificationStatusPreservingStorageFailure(NotificationStatus(
                kind: .authorizationDenied,
                detail: error.localizedDescription
            ))
        }
    }

    private func saveNotificationStatusPreservingStorageFailure(_ status: NotificationStatus) {
        guard statusStore.current().kind != .storageUnavailable else { return }
        statusStore.save(status)
    }
}
