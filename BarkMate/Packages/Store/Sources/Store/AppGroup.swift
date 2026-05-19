//
//  AppGroup.swift
//  Store
//

import Foundation

/// App Group 配置常量。主应用与所有 Extensions 共享。
public enum AppGroup {
    /// App Group identifier。与 entitlements 保持一致。
    public static let identifier: String = "group.com.barkmate.shared"

    /// 共享容器 URL（用于存储 SwiftData store、附件、pending queue 等）。
    public static var containerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            fatalError("App Group container not available. Check entitlements: \(identifier)")
        }
        return url
    }

    /// 共享 UserDefaults。
    public static var userDefaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: identifier) else {
            fatalError("Shared UserDefaults unavailable for suite: \(identifier)")
        }
        return defaults
    }

    /// SwiftData store 文件路径。
    public static var storeURL: URL {
        containerURL.appending(path: "BarkMate.sqlite")
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
        let fm = FileManager.default
        for dir in [resourcesDirectory, imagesDirectory] where !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
