//
//  AppGroup.swift
//  Store
//

import Foundation

public enum AppGroupError: LocalizedError {
    case containerUnavailable(identifier: String)
    case userDefaultsUnavailable(identifier: String)

    public var errorDescription: String? {
        switch self {
        case .containerUnavailable(let id):
            return "App Group container '\(id)' is unavailable. Check entitlements."
        case .userDefaultsUnavailable(let id):
            return "Shared UserDefaults for suite '\(id)' is unavailable."
        }
    }
}

/// App Group 配置常量。主应用与所有 Extensions 共享。
public enum AppGroup {
    /// App Group identifier。与 entitlements 保持一致。
    public static let identifier: String = "group.com.barkagent.shared"

    /// 抛错版共享容器 URL。优先使用此 API,让上层降级而非 crash。
    public static func resolveContainerURL() throws -> URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            throw AppGroupError.containerUnavailable(identifier: identifier)
        }
        return url
    }

    /// 兼容旧调用。容器不可用时仍然 crash,但新代码应改用 `resolveContainerURL()`。
    public static var containerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            fatalError("App Group container not available. Check entitlements: \(identifier)")
        }
        return url
    }

    /// 共享 UserDefaults。Suite 不可用时返回 .standard 作为兜底,避免 crash。
    public static var userDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// SwiftData store 文件路径(抛错版)。
    public static func resolveStoreURL() throws -> URL {
        try resolveContainerURL().appending(path: "BarkAgent.sqlite")
    }

    /// SwiftData store 文件路径。
    public static var storeURL: URL {
        containerURL.appending(path: "BarkAgent.sqlite")
    }

    /// 附件资源目录。
    public static var resourcesDirectory: URL {
        containerURL.appending(path: "resources", directoryHint: .isDirectory)
    }

    /// 推送图片目录。
    public static var imagesDirectory: URL {
        containerURL.appending(path: "images", directoryHint: .isDirectory)
    }

    /// 确保所有目录存在。
    public static func ensureDirectories() throws {
        let container = try resolveContainerURL()
        let fm = FileManager.default
        let dirs = [
            container.appending(path: "resources", directoryHint: .isDirectory),
            container.appending(path: "images", directoryHint: .isDirectory)
        ]
        for dir in dirs where !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
