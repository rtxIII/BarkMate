import XCTest
import SwiftData
@testable import BarkAgent
import BarkService
import Models
import Store

final class PendingQueueDrainerIntegrationTests: XCTestCase {

    private var pendingDirectory: URL!
    private var modelContainer: ModelContainer!

    override func setUpWithError() throws {
        pendingDirectory = FileManager.default.temporaryDirectory
            .appending(path: "BarkAgentAppTests-\(UUID().uuidString)/pending_messages", directoryHint: .isDirectory)
        modelContainer = try SharedModelContainer.makeInMemory()
    }

    override func tearDownWithError() throws {
        if let pendingDirectory {
            try? FileManager.default.removeItem(at: pendingDirectory.deletingLastPathComponent())
        }
        modelContainer = nil
        pendingDirectory = nil
    }

    @MainActor
    func testDrainArchivesPendingAgentPushIntoAppModelStore() async throws {
        let queue = PendingQueue(baseDirectory: pendingDirectory)
        try queue.enqueue(ParsedPush(
            id: "app-integration-step-1",
            title: "Build started",
            body: "Running app integration test",
            group: "codex",
            agentStatus: .running,
            taskID: "app-tests",
            progress: "1/2"
        ))

        let drainer = PendingQueueDrainer(
            modelContainer: modelContainer,
            pendingQueueBaseDirectory: pendingDirectory
        )
        await drainer.drain()

        let tasks = try modelContainer.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.aggregateKey, "codex::app-tests")
        XCTAssertEqual(tasks.first?.status, .running)
        XCTAssertEqual(tasks.first?.progress, "1/2")

        let steps = try modelContainer.mainContext.fetch(FetchDescriptor<AgentStep>())
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps.first?.title, "Build started")
        XCTAssertEqual(try queue.count(), 0)
    }
}
