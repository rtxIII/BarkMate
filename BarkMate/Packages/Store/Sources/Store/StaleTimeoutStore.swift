//
//  StaleTimeoutStore.swift
//  Store
//
//  Stale timeout 阈值持久化,存 App Group 共享 UserDefaults。
//  存 Int:正数 = 分钟;-1 = Off 哨兵;无 key = 默认 30。
//

import Foundation
import Models

public struct StaleTimeoutStore: @unchecked Sendable {

    private static let key = "staleTimeout.minutes"
    private static let offSentinel = -1

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroup.userDefaults
    }

    public func setThreshold(_ threshold: StaleThreshold) {
        switch threshold {
        case .off:
            defaults.set(Self.offSentinel, forKey: Self.key)
        case .minutes(let m):
            defaults.set(m, forKey: Self.key)
        }
    }

    public func threshold() -> StaleThreshold {
        guard defaults.object(forKey: Self.key) != nil else {
            return StaleThresholdCatalog.defaultThreshold
        }
        let raw = defaults.integer(forKey: Self.key)
        return raw == Self.offSentinel ? .off : .minutes(raw)
    }
}
