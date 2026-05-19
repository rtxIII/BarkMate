//
//  BarkClient.swift
//  BarkService
//
//  与 Bark 兼容服务器交互的 HTTP 客户端。
//  协议参考：doc/bark-protocol.md
//

import Foundation

public struct BarkClient: BarkClientProtocol {

    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    // MARK: - Register

    public func register(
        deviceToken: String,
        serverURL: URL,
        existingKey: String?
    ) async throws -> String {
        let body = formEncoded(["devicetoken": deviceToken, "key": existingKey])
        let request = try makeRequest(
            serverURL: serverURL,
            path: "/register",
            method: "POST",
            body: body
        )

        let (data, response) = try await sendRequest(request)
        try validateHTTPStatus(response)
        let payload = try decode(RegisterResponse.self, from: data)
        try validateBarkCode(payload.code, message: payload.message)

        guard let key = payload.data?.key, !key.isEmpty else {
            throw BarkAPIError.decodingFailed
        }
        return key
    }

    // MARK: - Ping

    public func ping(serverURL: URL) async throws -> Bool {
        let request = try makeRequest(
            serverURL: serverURL,
            path: "/ping",
            method: "GET",
            body: nil
        )

        let (data, response) = try await sendRequest(request)
        try validateHTTPStatus(response)
        let payload = try decode(PingResponse.self, from: data)
        return payload.code == HTTPStatus.ok
    }

    // MARK: - Internals

    private func makeRequest(
        serverURL: URL,
        path: String,
        method: String,
        body: Data?
    ) throws -> URLRequest {
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else {
            throw BarkAPIError.invalidURL
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = basePath + path
        guard let url = components.url else {
            throw BarkAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func sendRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            throw BarkAPIError.networkError(error)
        } catch {
            throw BarkAPIError.networkError(URLError(.unknown))
        }
    }

    private func validateHTTPStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw BarkAPIError.httpStatus(0)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BarkAPIError.httpStatus(http.statusCode)
        }
    }

    private func validateBarkCode(_ code: Int, message: String?) throws {
        guard code == HTTPStatus.ok else {
            throw BarkAPIError.serverError(code: code, message: message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw BarkAPIError.decodingFailed
        }
    }

    private func formEncoded(_ params: [String: String?]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed
        let body = params
            .compactMap { key, value -> String? in
                guard let value, !value.isEmpty else { return nil }
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }
}

// MARK: - Constants

private enum HTTPStatus {
    static let ok = 200
}

// MARK: - Response Models

private struct RegisterResponse: Decodable {
    let code: Int
    let message: String?
    let data: RegisterData?

    struct RegisterData: Decodable {
        let key: String
    }
}

private struct PingResponse: Decodable {
    let code: Int
    let message: String?
}
