//
//  BarkAPIError.swift
//  BarkService
//

import Foundation

/// Bark 服务器调用相关错误。
public enum BarkAPIError: Error, Equatable, Sendable {
    /// 无法构造合法 URL（baseURL + path 拼接失败）。
    case invalidURL
    /// URLSession 网络层错误。
    case networkError(URLError)
    /// HTTP 状态码非 2xx。
    case httpStatus(Int)
    /// HTTP 200 但服务器协议层失败（`code != 200`）。
    case serverError(code: Int, message: String?)
    /// 响应体无法按预期 schema 解码。
    case decodingFailed
}
