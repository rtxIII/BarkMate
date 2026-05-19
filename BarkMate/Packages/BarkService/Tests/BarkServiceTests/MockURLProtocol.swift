//
//  MockURLProtocol.swift
//  BarkServiceTests
//
//  URLProtocol 子类，供 BarkClient 测试拦截 URLSession 请求。
//

import Foundation

final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    /// 请求处理闭包：输入 URLRequest，返回 (response, body)。
    nonisolated(unsafe) static var stub: ((URLRequest) -> (HTTPURLResponse, Data))?

    /// 模拟网络层错误（优先级高于 stub）。
    nonisolated(unsafe) static var stubError: Error?

    /// 最近一次收到的请求（含从 bodyStream 读出的 httpBody）。
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    static func reset() {
        stub = nil
        stubError = nil
        lastRequest = nil
        lastBody = nil
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = Self.readBody(from: request)

        if let error = Self.stubError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let stub = Self.stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (response, data) = stub(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
}
