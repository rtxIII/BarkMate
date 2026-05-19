//
//  DraftManager.swift
//  Store
//
//  Memo 编辑器草稿持久化。存到 App Group 共享 UserDefaults。
//  - 每次文字变更通过 `save(draft:)` 保存（调用方决定节流时机）
//  - App 启动或打开编辑器时 `load()` 恢复
//  - 提交后 `clear()` 清除
//

import Foundation

public struct DraftManager: @unchecked Sendable {

    public struct Draft: Codable, Equatable, Sendable {
        public var body: String
        public var title: String?
        public var updatedAt: Date

        public init(body: String = "", title: String? = nil, updatedAt: Date = .now) {
            self.body = body
            self.title = title
            self.updatedAt = updatedAt
        }
    }

    private static let key = "memo.draft.v1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroup.userDefaults
    }

    public func load() -> Draft? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(Draft.self, from: data)
    }

    public func save(_ draft: Draft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: Self.key)
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
