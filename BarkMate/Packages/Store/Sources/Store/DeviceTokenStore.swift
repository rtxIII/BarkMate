//
//  DeviceTokenStore.swift
//  Store
//
//  APNs device token 持久化。共享到 App Group UserDefaults，
//  Extension 也可读（虽然 Phase 2 暂时不需要）。
//

import Foundation

public struct DeviceTokenStore: @unchecked Sendable {

    private static let key = "apns.deviceToken"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroup.userDefaults
    }

    public func save(token: String) {
        defaults.set(token, forKey: Self.key)
    }

    public func token() -> String? {
        defaults.string(forKey: Self.key)
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
