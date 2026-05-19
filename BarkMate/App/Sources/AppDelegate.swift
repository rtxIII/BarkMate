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

final class AppDelegate: NSObject, UIApplicationDelegate {

    @Injected(\.pushRegistrar) private var pushRegistrar: PushRegistrar
    @Injected(\.pendingQueueDrainer) private var pendingQueueDrainer: PendingQueueDrainer

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
            print("[BarkMate] handleDeviceToken finished")
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[BarkMate] ❌ APNs registration failed: \(error.localizedDescription)")
        print("[BarkMate]    full error: \(error)")
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
            }
        } catch {
            print("[BarkMate] ❌ Notification authorization error: \(error.localizedDescription)")
        }
    }
}
