import XCTest
import SwiftData
@testable import BarkService
import Models
import Store

final class PushArchiverTests: XCTestCase {

    private var storeURL: URL!
    private var container: ModelContainer!
    private var archiver: PushArchiver!

    override func setUpWithError() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appending(path: "BarkMateTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        storeURL = tmpDir.appending(path: "store.sqlite")
        container = try SharedModelContainer.make(storeURL: storeURL)
        archiver = PushArchiver(modelContainer: container)
    }

    override func tearDownWithError() throws {
        if let storeURL {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }
        archiver = nil
        container = nil
    }

    @MainActor
    func testArchiveInsertsItem() throws {
        let parsed = ParsedPush(
            id: UUID().uuidString,
            title: "t",
            body: "hello",
            tags: ["work"],
            group: "g"
        )
        try archiver.archive(parsed)

        let items = try container.mainContext.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.body, "hello")
        XCTAssertEqual(items.first?.type, .push)
        XCTAssertEqual(items.first?.tags, ["work"])
    }

    @MainActor
    func testArchiveIsIdempotentBySameID() throws {
        let pushId = UUID().uuidString
        let parsed = ParsedPush(id: pushId, body: "v1")
        try archiver.archive(parsed)

        let updated = ParsedPush(id: pushId, body: "v2", tags: ["updated"])
        try archiver.archive(updated)

        let items = try container.mainContext.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.body, "v2")
        XCTAssertEqual(items.first?.tags, ["updated"])
    }

    @MainActor
    func testArchiveHandlesNonUUIDPushID() throws {
        let parsed = ParsedPush(id: "arbitrary-string", body: "x")
        try archiver.archive(parsed)

        let items = try container.mainContext.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items.count, 1)

        // Idempotent on second call
        try archiver.archive(ParsedPush(id: "arbitrary-string", body: "y"))
        let items2 = try container.mainContext.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items2.count, 1)
        XCTAssertEqual(items2.first?.body, "y")
    }
}
