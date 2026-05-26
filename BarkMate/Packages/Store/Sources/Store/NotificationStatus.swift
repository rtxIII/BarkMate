//
//  NotificationStatus.swift
//  Store
//
//  通知 / APNs 健康状态。AppDelegate 在生命周期事件里写,SetupView 顶部
//  status banner 读 + 监听变更,出现可恢复异常时给用户明确入口。
//
//  存于 App Group UserDefaults,跨进程可读(Extension 暂不写,但保留可能)。
//

import Foundation

public enum NotificationStatusKind: String, Sendable, Equatable {
    /// 启动早期/未请求过权限。
    case unknown
    /// 通知权限授权 + APNs 注册成功 + 至少一个 server 状态为 ok。
    case ok
    /// 用户拒绝通知权限。需要去设置打开。
    case authorizationDenied
    /// 通知权限 OK 但 APNs 注册失败(沙箱 entitlement / 网络)。
    case apnsRegistrationFailed
    /// 至少一个 server 注册/ping 失败,需要用户去 Setup 检查。
    case serverUnreachable
}

public struct NotificationStatus: Sendable, Equatable {
    public let kind: NotificationStatusKind
    public let detail: String?
    public let updatedAt: Date

    public init(kind: NotificationStatusKind, detail: String? = nil, updatedAt: Date = .now) {
        self.kind = kind
        self.detail = detail
        self.updatedAt = updatedAt
    }

    public static let unknown = NotificationStatus(kind: .unknown)
}

/// AppGroup UserDefaults 持久化 NotificationStatus。
/// `UserDefaults` 不是 Sendable,但本类型只在主线程被访问;用 `@unchecked Sendable`
/// 与 `DeviceTokenStore` 保持一致。
public struct NotificationStatusStore: @unchecked Sendable {

    private static let kindKey = "notif.status.kind"
    private static let detailKey = "notif.status.detail"
    private static let updatedAtKey = "notif.status.updatedAt"
    /// 状态变更跨视图通知名(供 SwiftUI .onReceive 监听)。
    public static let didChangeNotification = Notification.Name("com.barkmate.notif.status.didChange")

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroup.userDefaults
    }

    public func current() -> NotificationStatus {
        let raw = defaults.string(forKey: Self.kindKey) ?? NotificationStatusKind.unknown.rawValue
        let kind = NotificationStatusKind(rawValue: raw) ?? .unknown
        let detail = defaults.string(forKey: Self.detailKey)
        let updatedAt = (defaults.object(forKey: Self.updatedAtKey) as? Date) ?? .distantPast
        return NotificationStatus(kind: kind, detail: detail, updatedAt: updatedAt)
    }

    public func save(_ status: NotificationStatus) {
        defaults.set(status.kind.rawValue, forKey: Self.kindKey)
        if let detail = status.detail {
            defaults.set(detail, forKey: Self.detailKey)
        } else {
            defaults.removeObject(forKey: Self.detailKey)
        }
        defaults.set(status.updatedAt, forKey: Self.updatedAtKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
