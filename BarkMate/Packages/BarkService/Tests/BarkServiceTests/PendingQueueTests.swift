import XCTest
@testable import BarkService
import Models

final class PendingQueueTests: XCTestCase {

    private var tempDir: URL!
    private var queue: PendingQueue!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appending(path: "PendingQueueTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        queue = PendingQueue(baseDirectory: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testEnqueueAndDrainSingle() throws {
        let parsed = ParsedPush(id: "msg-1", body: "hello", tags: ["work"])
        try queue.enqueue(parsed)

        XCTAssertEqual(try queue.count(), 1)

        let drained = try queue.drain()
        XCTAssertEqual(drained.count, 1)
        XCTAssertEqual(drained.first?.id, "msg-1")
        XCTAssertEqual(drained.first?.body, "hello")
        XCTAssertEqual(drained.first?.tags, ["work"])

        // drain should leave queue empty
        XCTAssertEqual(try queue.count(), 0)
    }

    func testEnqueueIsIdempotentBySameID() throws {
        try queue.enqueue(ParsedPush(id: "same-id", body: "v1"))
        try queue.enqueue(ParsedPush(id: "same-id", body: "v2"))
        XCTAssertEqual(try queue.count(), 1)

        let drained = try queue.drain()
        XCTAssertEqual(drained.count, 1)
        XCTAssertEqual(drained.first?.body, "v2")
    }

    func testDrainEmpty() throws {
        XCTAssertEqual(try queue.drain(), [])
    }

    func testDrainMultiplePreservesAll() throws {
        try queue.enqueue(ParsedPush(id: "a", body: "1"))
        try queue.enqueue(ParsedPush(id: "b", body: "2"))
        try queue.enqueue(ParsedPush(id: "c", body: "3"))
        XCTAssertEqual(try queue.count(), 3)

        let drained = try queue.drain()
        XCTAssertEqual(Set(drained.map(\.id)), ["a", "b", "c"])
        XCTAssertEqual(try queue.count(), 0)
    }
}
