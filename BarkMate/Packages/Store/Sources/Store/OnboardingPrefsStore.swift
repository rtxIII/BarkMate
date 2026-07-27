//
//  OnboardingPrefsStore.swift
//  Store
//
//  Onboarding 偏好持久化,存 App Group 共享 UserDefaults。
//  目前只承载空态 hero 卡的「不再提示」开关:无 key = 未 dismiss(默认展示)。
//

import Foundation

public struct OnboardingPrefsStore: @unchecked Sendable {

    private static let emptyStateHeroDismissedKey = "onboarding.emptyStateHeroDismissed"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroup.userDefaults
    }

    public func dismissEmptyStateHero() {
        defaults.set(true, forKey: Self.emptyStateHeroDismissedKey)
    }

    public func isEmptyStateHeroDismissed() -> Bool {
        defaults.bool(forKey: Self.emptyStateHeroDismissedKey)
    }
}
