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
    func testArchiveAgentPushUpsertsTaskAndInsertsStep() throws {
        let parsed = ParsedPush(
            id: UUID().uuidString,
            title: "t",
            body: "hello",
            tags: ["work"],
            group: "g",
            agentStatus: .running,
            taskID: "task-1",
            progress: "1/3"
        )
        try archiver.archive(parsed)

        let tasks = try container.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.aggregateKey, "g::task-1")
        XCTAssertEqual(tasks.first?.status, .running)
        XCTAssertEqual(tasks.first?.progress, "1/3")

        let steps = try container.mainContext.fetch(FetchDescriptor<AgentStep>())
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps.first?.body, "hello")
        XCTAssertEqual(steps.first?.progress, "1/3")
        XCTAssertEqual(tasks.first?.steps.count, 1)
    }

    @MainActor
    func testAgentPushAggregatesByAgentAndTaskID() throws {
        let parsed = ParsedPush(
            id: "step-1",
            title: "started",
            body: "v1",
            group: "ci",
            agentStatus: .running,
            taskID: "build",
            progress: "1/2"
        )
        try archiver.archive(parsed)

        let updated = ParsedPush(
            id: "step-2",
            title: "finished",
            body: "v2",
            group: "ci",
            agentStatus: .done,
            taskID: "build",
            progress: "2/2"
        )
        try archiver.archive(updated)

        let tasks = try container.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.status, .done)
        XCTAssertEqual(tasks.first?.latestStepTitle, "finished")
        XCTAssertEqual(tasks.first?.progress, "2/2")

        let steps = try container.mainContext.fetch(FetchDescriptor<AgentStep>())
        XCTAssertEqual(steps.count, 2)
        XCTAssertEqual(tasks.first?.steps.count, 2)
    }

    @MainActor
    func testOldProtocolPushArchivesIncomingMemoByID() throws {
        let parsed = ParsedPush(id: "arbitrary-string", body: "x")
        try archiver.archive(parsed)

        let memos = try container.mainContext.fetch(FetchDescriptor<Memo>())
        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos.first?.source, .incoming)
        XCTAssertEqual(memos.first?.body, "x")

        // Idempotent on second call
        try archiver.archive(ParsedPush(id: "arbitrary-string", body: "y"))
        let memos2 = try container.mainContext.fetch(FetchDescriptor<Memo>())
        XCTAssertEqual(memos2.count, 1)
        XCTAssertEqual(memos2.first?.body, "y")
    }

    @MainActor
    func testAgentPushRetransmitIsIdempotent() throws {
        // C1: 同 parsed.id 两次 archive (APNs 重传场景) → 1 task + 1 step。
        let parsed = ParsedPush(
            id: "stable-push-1",
            title: "running",
            body: "step body",
            group: "ci",
            agentStatus: .running,
            taskID: "build",
            progress: "1/3"
        )
        try archiver.archive(parsed)
        try archiver.archive(parsed)

        let tasks = try container.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(tasks.count, 1)
        let steps = try container.mainContext.fetch(FetchDescriptor<AgentStep>())
        XCTAssertEqual(steps.count, 1, "retransmitted push should not duplicate step")
        XCTAssertEqual(tasks.first?.steps.count, 1)
    }

    @MainActor
    func testManualMemoArchiveUsesManualSource() throws {
        let parsed = ParsedPush(id: UUID().uuidString, title: "note", body: "manual")
        try archiver.archive(parsed, fallbackMemoSource: .manual)

        let memos = try container.mainContext.fetch(FetchDescriptor<Memo>())
        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos.first?.source, .manual)
        XCTAssertEqual(memos.first?.title, "note")
    }
}
