//
//  AlertSoundStore.swift
//  Store
//
//  Per-status 声音偏好,存 App Group 共享 UserDefaults。App 写、NSE 读。
//  存声音 id 字符串(如 "bell"),不存文件名。
//

import Foundation
import Models

public struct AlertSoundStore: @unchecked Sendable {

    /// 可单独覆盖的 status;其余用全局默认。
    public static let overridableStatuses: [AgentStatus] = [
        .waitingInput, .blocked, .failed
    ]

    private static let keyPrefix = "alertSound."
    private static let defaultKey = keyPrefix + "default"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroup.userDefaults
    }

    // MARK: - 全局默认

    public func setGlobalDefault(id: String) {
        defaults.set(id, forKey: Self.defaultKey)
    }

    public func globalDefaultID() -> String? {
        defaults.string(forKey: Self.defaultKey)
    }

    // MARK: - Per-status override

    public func setOverride(id: String?, for status: AgentStatus) {
        let key = Self.keyPrefix + status.rawValue
        if let id {
            defaults.set(id, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func overrideID(for status: AgentStatus) -> String? {
        defaults.string(forKey: Self.keyPrefix + status.rawValue)
    }

    // MARK: - 解析(回落链)

    /// status override → 全局默认 → nil(nil 表示不覆盖发送方声音)。
    public func resolvedSoundID(for status: AgentStatus) -> String? {
        overrideID(for: status) ?? globalDefaultID()
    }
}
