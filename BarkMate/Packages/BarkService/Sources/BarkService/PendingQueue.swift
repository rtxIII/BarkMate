//
//  PendingQueue.swift
//  BarkService
//
//  Extension 写 SwiftData 失败时的降级通道（参考 bark-server ArchiveProcessor 方案）。
//  - Extension 把 ParsedPush JSON 序列化到 App Group 的 `pending_messages/<sha>.json`
//  - 主 App 通过 Darwin 通知或启动时调 `drain()` 消费后删除文件
//
//  为什么不用 plist：Codable + JSON 最简，plist 对 [String] / 嵌套 Codable 支持有坑。
//

import Foundation
import CryptoKit
import Store

public struct PendingQueue: @unchecked Sendable {

    public static let directoryName = "pending_messages"

    private let baseDirectory: URL
    private let fileManager: FileManager

    /// 默认使用 App Group 共享容器。测试传入自定义目录。
    public init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = AppGroup.containerURL.appending(
                path: PendingQueue.directoryName,
                directoryHint: .isDirectory
            )
        }
        self.fileManager = fileManager
    }

    /// 入队：写一个 JSON 文件。文件名基于 parsed.id 哈希以保持幂等。
    public func enqueue(_ parsed: ParsedPush) throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let fileURL = baseDirectory.appending(path: filename(for: parsed.id))
        let data = try JSONEncoder().encode(parsed)
        try data.write(to: fileURL, options: .atomic)
    }

    /// 返回所有可解码的 pending，但保留文件，等待调用方完成持久化后显式确认。
    /// 读取/反序列化失败的文件被跳过并保留，以便下次重试。
    public func pendingMessages() throws -> [ParsedPush] {
        guard fileManager.fileExists(atPath: baseDirectory.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil
        )
        var results: [ParsedPush] = []
        for url in urls where url.pathExtension == "json" {
            guard
                let data = try? Data(contentsOf: url),
                let parsed = try? JSONDecoder().decode(ParsedPush.self, from: data)
            else {
                continue
            }
            results.append(parsed)
        }
        return results
    }

    /// 确认单条 pending 已持久化并删除对应文件。重复确认保持幂等。
    public func acknowledge(_ parsed: ParsedPush) throws {
        let fileURL = baseDirectory.appending(path: filename(for: parsed.id))
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    /// 排空：返回所有 pending 并删文件。读取/反序列化失败的文件被跳过（但保留以便下次重试）。
    public func drain() throws -> [ParsedPush] {
        let results = try pendingMessages()
        for parsed in results {
            try? acknowledge(parsed)
        }
        return results
    }

    /// 当前队列长度（不消费）。
    public func count() throws -> Int {
        guard fileManager.fileExists(atPath: baseDirectory.path) else { return 0 }
        let urls = try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil
        )
        return urls.filter { $0.pathExtension == "json" }.count
    }

    // MARK: - Internals

    private func filename(for pushID: String) -> String {
        let hash = SHA256.hash(data: Data(pushID.utf8))
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        return "\(hex).json"
    }
}
