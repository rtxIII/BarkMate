//
//  BarkClientTests.swift
//  BarkServiceTests
//

// swiftlint:disable force_unwrapping

import XCTest
@testable import BarkService

final class BarkClientTests: XCTestCase {

    private var client: BarkClient!
    private let serverURL = URL(string: "https://api.day.app")!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        client = BarkClient(session: MockURLProtocol.makeSession())
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
        super.tearDown()
    }

    // MARK: - register

    func testRegisterSuccessReturnsKey() async throws {
        MockURLProtocol.stub = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body = #"{"code":200,"message":"success","data":{"key":"server-issued-key"}}"#
            return (response, Data(body.utf8))
        }

        let key = try await client.register(
            deviceToken: "abc123",
            serverURL: serverURL,
            existingKey: nil
        )
        XCTAssertEqual(key, "server-issued-key")
    }

    func testRegisterPostsFormBody() async throws {
        MockURLProtocol.stub = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body = #"{"code":200,"data":{"key":"k"}}"#
            return (response, Data(body.utf8))
        }

        _ = try await client.register(
            deviceToken: "token-xyz",
            serverURL: serverURL,
            existingKey: "prev-key"
        )

        let captured = MockURLProtocol.lastRequest
        XCTAssertEqual(captured?.httpMethod, "POST")
        XCTAssertEqual(captured?.url?.path, "/register")
        XCTAssertEqual(
            captured?.value(forHTTPHeaderField: "Content-Type"),
            "application/x-www-form-urlencoded"
        )

        let bodyString = String(data: MockURLProtocol.lastBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(bodyString.contains("devicetoken=token-xyz"))
        XCTAssertTrue(bodyString.contains("key=prev-key"))
    }

    func testRegisterServerErrorThrowsServerError() async {
        MockURLProtocol.stub = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body = #"{"code":500,"message":"server down"}"#
            return (response, Data(body.utf8))
        }

        do {
            _ = try await client.register(deviceToken: "x", serverURL: serverURL, existingKey: nil)
            XCTFail("Expected BarkAPIError.serverError")
        } catch let BarkAPIError.serverError(code, message) {
            XCTAssertEqual(code, 500)
            XCTAssertEqual(message, "server down")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRegisterNetworkErrorWrapped() async {
        MockURLProtocol.stubError = URLError(.notConnectedToInternet)

        do {
            _ = try await client.register(deviceToken: "x", serverURL: serverURL, existingKey: nil)
            XCTFail("Expected BarkAPIError.networkError")
        } catch let BarkAPIError.networkError(urlError) {
            XCTAssertEqual(urlError.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - ping

    func testPingOk() async throws {
        MockURLProtocol.stub = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body = #"{"code":200,"message":"pong"}"#
            return (response, Data(body.utf8))
        }

        let ok = try await client.ping(serverURL: serverURL)
        XCTAssertTrue(ok)
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/ping")
    }

    func testPingHttpFailureThrows() async {
        MockURLProtocol.stub = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }

        do {
            _ = try await client.ping(serverURL: serverURL)
            XCTFail("Expected BarkAPIError.httpStatus(500)")
        } catch let BarkAPIError.httpStatus(code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// swiftlint:enable force_unwrapping
