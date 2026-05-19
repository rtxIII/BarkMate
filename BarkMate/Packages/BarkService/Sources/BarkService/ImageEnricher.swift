//
//  ImageEnricher.swift
//  BarkService
//
//  下载 userInfo["image"] 指向的远程图片并附加为 UNNotificationAttachment，
//  让系统通知 banner 显示图片预览。
//  - 超时 10s（Extension 总时长 30s 硬上限）
//  - 最大 10MB 缓冲（Extension 24MB 内存预算）
//  - 失败静默返回，不影响推送下发
//

import Foundation
import UserNotifications

public struct ImageEnricher: Sendable {

    public static let defaultTimeout: TimeInterval = 10
    public static let maxBytes = 10 * 1024 * 1024  // 10MB

    private let session: URLSession
    private let timeout: TimeInterval
    private let downloadDirectory: URL

    public init(
        session: URLSession = .shared,
        timeout: TimeInterval = ImageEnricher.defaultTimeout,
        downloadDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory())
    ) {
        self.session = session
        self.timeout = timeout
        self.downloadDirectory = downloadDirectory
    }

    /// 解析 userInfo["image"] → 下载 → 附加到 content.attachments。
    /// 返回是否实际附加了图片（调用方可用于日志/遥测）。
    @discardableResult
    public func attachImageIfNeeded(
        userInfo: [AnyHashable: Any],
        to content: UNMutableNotificationContent
    ) async -> Bool {
        guard
            let imageString = userInfo["image"] as? String,
            let url = URL(string: imageString)
        else { return false }

        do {
            let fileURL = try await downloadToTempFile(url: url)
            let attachment = try UNNotificationAttachment(
                identifier: UUID().uuidString,
                url: fileURL
            )
            content.attachments = [attachment]
            return true
        } catch {
            return false
        }
    }

    // MARK: - Internals

    private func downloadToTempFile(url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        let (data, response) = try await session.data(for: request)
        guard
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else {
            throw EnrichError.httpError
        }
        guard data.count <= Self.maxBytes else {
            throw EnrichError.oversize
        }

        let ext = suggestedExtension(from: response, fallback: url.pathExtension)
        let filename = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let fileURL = downloadDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func suggestedExtension(from response: URLResponse, fallback: String) -> String {
        if let mimeType = response.mimeType {
            switch mimeType.lowercased() {
            case "image/png": return "png"
            case "image/jpeg": return "jpg"
            case "image/gif": return "gif"
            case "image/webp": return "webp"
            default: break
            }
        }
        return fallback
    }

    enum EnrichError: Error {
        case httpError
        case oversize
    }
}
