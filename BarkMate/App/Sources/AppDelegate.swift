//
//  AppDelegate.swift
//  BarkMate
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

final class AppDelegate: NSObject, UIApplicationDelegate {

    @Injected(\.pushRegistrar) private var pushRegistrar: PushRegistrar
    @Injected(\.pendingQueueDrainer) private var pendingQueueDrainer: PendingQueueDrainer
    @Injected(\.notificationStatusStore) private var statusStore: NotificationStatusStore

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[BarkMate] AppDelegate didFinishLaunching")
        Task { @MainActor in
            pushRegistrar.seedDefaultServerIfNeeded()
            print("[BarkMate] seedDefaultServerIfNeeded done")
            pendingQueueDrainer.start()
            await requestAuthorizationAndRegister(application: application)
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[BarkMate] APNs device token received: \(hex.prefix(8))... (len=\(hex.count))")
        Task { @MainActor in
            await pushRegistrar.handleDeviceToken(hex)
            // PushRegistrar 内部会按 server 健康度更新 status;此处兜底为 ok。
            if statusStore.current().kind != .serverUnreachable {
                statusStore.save(NotificationStatus(kind: .ok))
            }
            print("[BarkMate] handleDeviceToken finished")
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[BarkMate] ❌ APNs registration failed: \(error.localizedDescription)")
        print("[BarkMate]    full error: \(error)")
        statusStore.save(NotificationStatus(
            kind: .apnsRegistrationFailed,
            detail: error.localizedDescription
        ))
    }

    @MainActor
    private func requestAuthorizationAndRegister(application: UIApplication) async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            print("[BarkMate] Notification authorization granted=\(granted)")
            if granted {
                application.registerForRemoteNotifications()
                print("[BarkMate] registerForRemoteNotifications called, waiting for callback...")
            } else {
                statusStore.save(NotificationStatus(
                    kind: .authorizationDenied,
                    detail: "Notification permission was denied"
                ))
            }
        } catch {
            print("[BarkMate] ❌ Notification authorization error: \(error.localizedDescription)")
            statusStore.save(NotificationStatus(
                kind: .authorizationDenied,
                detail: error.localizedDescription
            ))
        }
    }
}
