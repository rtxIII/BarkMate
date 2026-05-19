// swiftlint:disable force_unwrapping

import XCTest
import UserNotifications
@testable import BarkService

final class ImageEnricherTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        MockURLProtocol.reset()
        tempDir = FileManager.default.temporaryDirectory
            .appending(path: "ImageEnricherTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        MockURLProtocol.reset()
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeEnricher() -> ImageEnricher {
        ImageEnricher(
            session: MockURLProtocol.makeSession(),
            timeout: 5,
            downloadDirectory: tempDir
        )
    }

    func testNoImageFieldReturnsFalse() async {
        let content = UNMutableNotificationContent()
        let attached = await makeEnricher().attachImageIfNeeded(
            userInfo: ["aps": ["alert": ["body": "x"]]],
            to: content
        )
        XCTAssertFalse(attached)
        XCTAssertTrue(content.attachments.isEmpty)
    }

    func testSuccessfulAttach() async {
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG magic
        MockURLProtocol.stub = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/png"]
            )!
            return (response, pngData)
        }

        let content = UNMutableNotificationContent()
        let attached = await makeEnricher().attachImageIfNeeded(
            userInfo: ["image": "https://example.com/pic.png"],
            to: content
        )
        XCTAssertTrue(attached)
        XCTAssertEqual(content.attachments.count, 1)
        XCTAssertTrue(content.attachments[0].url.pathExtension == "png")
    }

    func testHttpFailureReturnsFalse() async {
        MockURLProtocol.stub = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }

        let content = UNMutableNotificationContent()
        let attached = await makeEnricher().attachImageIfNeeded(
            userInfo: ["image": "https://example.com/missing.png"],
            to: content
        )
        XCTAssertFalse(attached)
        XCTAssertTrue(content.attachments.isEmpty)
    }

    func testInvalidURLIgnored() async {
        let content = UNMutableNotificationContent()
        let attached = await makeEnricher().attachImageIfNeeded(
            userInfo: ["image": ""],
            to: content
        )
        XCTAssertFalse(attached)
    }
}

// swiftlint:enable force_unwrapping
