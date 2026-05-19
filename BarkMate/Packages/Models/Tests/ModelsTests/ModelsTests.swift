//
//  ModelsTests.swift
//  ModelsTests
//

import XCTest
import SwiftData
@testable import Models

final class ModelsTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: AgentTask.self, AgentStep.self, Memo.self,
            Resource.self, Server.self, CryptoConfig.self,
            configurations: config
        )
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - AgentTask

    @MainActor
    func testAggregateKeyHelper() {
        XCTAssertEqual(AgentTask.aggregateKey(agentID: "ci", taskID: "build-42"), "ci::build-42")
        XCTAssertEqual(AgentTask.aggregateKey(agentID: "ci", taskID: nil), "ci::_")
    }

    @MainActor
    func testInsertAndFetchAgentTask() throws {
        let context = container.mainContext
        let key = AgentTask.aggregateKey(agentID: "ci", taskID: "build-42")
        let task = AgentTask(
            aggregateKey: key,
            agentID: "ci",
            taskID: "build-42",
            displayName: "CI Build #42",
            status: .running,
            latestStepTitle: "compiling",
            progress: "3/7"
        )
        context.insert(task)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.aggregateKey, key)
        XCTAssertEqual(fetched.first?.status, .running)
        XCTAssertEqual(fetched.first?.progress, "3/7")
    }

    @MainActor
    func testAgentTaskStatusRoundTrip() throws {
        let context = container.mainContext
        let task = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "a", taskID: nil),
            agentID: "a",
            displayName: "A",
            status: .waitingInput
        )
        context.insert(task)
        try context.save()

        // 用 statusRaw 直接做谓词验证 rawValue 落库正确（"waiting_input"）。
        let predicate = #Predicate<AgentTask> { $0.statusRaw == "waiting_input" }
        let fetched = try context.fetch(FetchDescriptor<AgentTask>(predicate: predicate))
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.status, .waitingInput)
    }

    @MainActor
    func testAggregateKeyUniqueUpsertSemantics() throws {
        // SwiftData 的 @Attribute(.unique) 语义是 upsert（与 Core Data 不同）：
        // 同一 unique key 第二次 insert 会覆盖既有对象的字段，而不是抛错。
        // 业务层（AgentTaskStore.upsert）应先 fetch 后再决定 insert/update，不依赖此自动 upsert。
        let context = container.mainContext
        let key = AgentTask.aggregateKey(agentID: "dup", taskID: "t1")
        let first = AgentTask(aggregateKey: key, agentID: "dup", taskID: "t1", displayName: "first")
        context.insert(first)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<AgentTask>()).count, 1)

        let second = AgentTask(aggregateKey: key, agentID: "dup", taskID: "t1", displayName: "second")
        context.insert(second)
        try context.save()

        // upsert 后表里仍只剩 1 条；displayName 被覆盖。
        let fetched = try context.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(fetched.count, 1, "SwiftData should upsert by unique aggregateKey, not duplicate")
        XCTAssertEqual(fetched.first?.displayName, "second")
    }

    // MARK: - AgentStep cascade

    @MainActor
    func testAgentStepCascadeDelete() throws {
        let context = container.mainContext
        let task = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "ci", taskID: "build-1"),
            agentID: "ci",
            taskID: "build-1",
            displayName: "build-1"
        )
        let step1 = AgentStep(status: .running, body: "step1")
        let step2 = AgentStep(status: .done, body: "step2")
        task.steps = [step1, step2]
        context.insert(task)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<AgentStep>()).count, 2)

        context.delete(task)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<AgentStep>()).count, 0)
    }

    // MARK: - Memo

    @MainActor
    func testMemoManualSource() throws {
        let context = container.mainContext
        let memo = Memo(
            source: .manual,
            title: "note",
            body: "hello #tag",
            bodyType: .markdown,
            tags: ["tag"]
        )
        context.insert(memo)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Memo>())
        XCTAssertEqual(fetched.first?.source, .manual)
        XCTAssertEqual(fetched.first?.bodyType, .markdown)
        XCTAssertEqual(fetched.first?.tags, ["tag"])
    }

    @MainActor
    func testMemoIncomingSource() throws {
        let context = container.mainContext
        let serverID = UUID()
        let memo = Memo(
            source: .incoming,
            title: "Bark push",
            body: "from server",
            group: "alerts",
            sourceServerID: serverID
        )
        context.insert(memo)
        try context.save()

        // 用 sourceRaw 直接做谓词，验证 rawValue 序列化无误。
        let predicate = #Predicate<Memo> { $0.sourceRaw == "incoming" }
        let fetched = try context.fetch(FetchDescriptor<Memo>(predicate: predicate))
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.source, .incoming)
        XCTAssertEqual(fetched.first?.sourceServerID, serverID)
        XCTAssertEqual(fetched.first?.group, "alerts")
    }

    // MARK: - Resource

    @MainActor
    func testResourceAttachedToStep() throws {
        let context = container.mainContext
        let task = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "a", taskID: "1"),
            agentID: "a",
            taskID: "1",
            displayName: "a"
        )
        let step = AgentStep(status: .running, body: "with image")
        let resource = Resource(
            filename: "photo.jpg",
            mimeType: "image/jpeg",
            localPath: "resources/photo.jpg",
            size: 1024
        )
        step.resources = [resource]
        task.steps = [step]
        context.insert(task)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Resource>()).count, 1)

        // 删 task → cascade 删 step → cascade 删 resource
        context.delete(task)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Resource>()).count, 0)
    }

    @MainActor
    func testResourceAttachedToMemo() throws {
        let context = container.mainContext
        let memo = Memo(source: .manual, body: "with photo")
        let resource = Resource(
            filename: "selfie.jpg",
            mimeType: "image/jpeg",
            localPath: "resources/selfie.jpg",
            size: 2048
        )
        memo.resources = [resource]
        context.insert(memo)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Resource>()).count, 1)

        context.delete(memo)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Resource>()).count, 0)
    }

    // MARK: - Server / CryptoConfig (regression — 不变保留)

    @MainActor
    func testServerStateEnum() throws {
        let context = container.mainContext
        let server = Server(
            name: "default",
            address: "https://api.day.app",
            key: "test-key",
            state: .ok
        )
        context.insert(server)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Server>())
        XCTAssertEqual(fetched.first?.state, .ok)
        XCTAssertEqual(fetched.first?.address, "https://api.day.app")
    }

    @MainActor
    func testCryptoConfigDefaults() throws {
        let context = container.mainContext
        let server = Server(address: "https://example.com", key: "k")
        context.insert(server)

        let crypto = CryptoConfig(
            serverID: server.id,
            algorithm: .aes256,
            mode: .cbc,
            keychainKeyRef: "barkmate.crypto.\(server.id).key",
            keychainIVRef: "barkmate.crypto.\(server.id).iv"
        )
        context.insert(crypto)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CryptoConfig>())
        XCTAssertEqual(fetched.first?.algorithm, .aes256)
        XCTAssertEqual(fetched.first?.mode, .cbc)
        XCTAssertTrue(fetched.first?.isEnabled ?? false)
    }
}
