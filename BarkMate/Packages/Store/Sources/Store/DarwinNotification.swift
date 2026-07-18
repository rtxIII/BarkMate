//
//  DarwinNotification.swift
//  Store
//
//  Extension 与主应用之间的跨进程通知通道。
//  Phase 2 将扩展：NotificationServiceExtension 写入新消息后发出通知，
//  主应用监听后刷新 @Query。
//

import Foundation

public enum DarwinNotification {

    /// 通知名常量。
    public enum Name: String {
        /// 数据层有新写入，主 App 应刷新 @Query。
        ///
        /// 触发方：NotificationServiceExtension（写 AgentStep / Memo incoming）、
        /// Share Extension（写 Memo manual）、PendingQueueDrainer。
        ///
        /// 通用刷新信号，不携带 payload；订阅方自行 fetch 最新数据。
        /// case 名 `itemDidArrive` 是 v0.2 Item-中心设计的命名遗物，
        /// 2.0.5 重命名 UI 时一并改为 `dataDidArrive`。
        case itemDidArrive = "com.barkagent.darwin.itemDidArrive"
        /// Pending queue 有新任务。
        case pendingTaskQueued = "com.barkagent.darwin.pendingTaskQueued"
    }

    /// 发送一个 Darwin notification（跨进程）。
    public static func post(_ name: Name) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name.rawValue as CFString),
            nil,
            nil,
            true
        )
    }

    /// 注册监听。回调在一个后台 dispatch queue 上触发；调用方自行切线程。
    public static func observe(
        _ name: Name,
        using handler: @escaping @Sendable () -> Void
    ) -> DarwinObserver {
        DarwinObserver(name: name, handler: handler)
    }
}

/// 持有 Darwin notification 监听生命周期。释放时自动反注册。
public final class DarwinObserver {
    private let name: DarwinNotification.Name
    private let handler: @Sendable () -> Void
    private let box: ObserverBox

    init(name: DarwinNotification.Name, handler: @escaping @Sendable () -> Void) {
        self.name = name
        self.handler = handler
        self.box = ObserverBox(handler: handler)

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(box).toOpaque()

        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let box = Unmanaged<ObserverBox>.fromOpaque(observer).takeUnretainedValue()
                box.handler()
            },
            name.rawValue as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(box).toOpaque()
        CFNotificationCenterRemoveObserver(
            center,
            observer,
            CFNotificationName(name.rawValue as CFString),
            nil
        )
    }
}

private final class ObserverBox: @unchecked Sendable {
    let handler: @Sendable () -> Void
    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }
}
