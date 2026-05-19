//
//  BarkClientProtocol.swift
//  BarkService
//

import Foundation

/// Bark 服务器客户端协议。具体实现见 `BarkClient`，测试可用 mock 替换。
public protocol BarkClientProtocol: Sendable {
    /// 注册或更新设备 token。
    /// - Parameters:
    ///   - deviceToken: APNs 注册返回的 hex token
    ///   - serverURL: Bark 服务器根 URL（例：`https://api.day.app`）
    ///   - existingKey: 已分配的 server key；首次注册传 nil
    /// - Returns: 服务器分配（或保留）的 key
    func register(
        deviceToken: String,
        serverURL: URL,
        existingKey: String?
    ) async throws -> String

    /// 健康检查。
    /// - Returns: 服务器返回 `code == 200` 时为 true
    func ping(serverURL: URL) async throws -> Bool
}
