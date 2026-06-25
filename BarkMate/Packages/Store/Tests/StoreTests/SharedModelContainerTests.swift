//
//  SharedModelContainerTests.swift
//  StoreTests
//
//  验证 Phase 2 的核心假设：两个独立 ModelContainer 指向同一 SQLite URL
//  能否看到彼此写入。模拟主 App ↔ NotificationServiceExtension 的数据共享场景。
//
//  App Group 的真实跨进程测试需在 Simulator 下运行；此处用临时目录作为替代
//  （技术基础相同：同一 sqlite 文件 + WAL 模式）。
//

import XCTest
import SwiftData
import Models
@testable import Store

final class SharedModelContainerTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appending(path: "BarkAgentTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        storeURL = tmpDir.appending(path: "store.sqlite")
    }

    override func tearDownWithError() throws {
        if let storeURL {
            let parent = storeURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: parent)
        }
    }

    /// Writer 写入一条 AgentTask，Reader 用全新 container 在同一 sqlite 上能读到。
    @MainActor
    func testTwoContainersShareAgentTask() throws {
        try autoreleasepool {
            let writer = try SharedModelContainer.make(storeURL: storeURL)
            let task = AgentTask(
                aggregateKey: AgentTask.aggregateKey(agentID: "ci", taskID: "build-1"),
                agentID: "ci",
                taskID: "build-1",
                displayName: "CI Build #1",
                status: .running
            )
            writer.mainContext.insert(task)
            try writer.mainContext.save()
        }

        let reader = try SharedModelContainer.make(storeURL: storeURL)
        let fetched = try reader.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.displayName, "CI Build #1")
        XCTAssertEqual(fetched.first?.status, .running)
    }

    /// 模拟 NotificationServiceExtension 写入 AgentTask + AgentStep，主 App 启动后能读到完整层级。
    @MainActor
    func testExtensionWritesAgentTaskWithSteps() throws {
        try autoreleasepool {
            let ext = try SharedModelContainer.make(storeURL: storeURL)
            let task = AgentTask(
                aggregateKey: AgentTask.aggregateKey(agentID: "claude-code", taskID: "session-7"),
                agentID: "claude-code",
                taskID: "session-7",
                displayName: "claude-code session-7",
                status: .running,
                sourceServerID: UUID()
            )
            let step = AgentStep(
                task: task,
                status: .running,
                title: "compiling src/",
                body: "step 3/7"
            )
            task.steps = [step]
            ext.mainContext.insert(task)
            try ext.mainContext.save()
        }

        let app = try SharedModelContainer.make(storeURL: storeURL)
        let tasks = try app.mainContext.fetch(FetchDescriptor<AgentTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.steps.count, 1)
        XCTAssertEqual(tasks.first?.steps.first?.title, "compiling src/")

        let steps = try app.mainContext.fetch(FetchDescriptor<AgentStep>())
        XCTAssertEqual(steps.count, 1)
    }

    /// NSE 多次写入 incoming AgentInboxItem 后,主 App 重启能完整读到所有条目。
    @MainActor
    func testMultiWriterInboxItemsCoexist() throws {
        try autoreleasepool {
            let containerA = try SharedModelContainer.make(storeURL: storeURL)
            for index in 0..<5 {
                containerA.mainContext.insert(
                    AgentInboxItem(body: "first-batch-\(index)", group: "build")
                )
            }
            try containerA.mainContext.save()
        }

        try autoreleasepool {
            let containerB = try SharedModelContainer.make(storeURL: storeURL)
            for index in 0..<5 {
                containerB.mainContext.insert(
                    AgentInboxItem(body: "second-batch-\(index)", group: "alerts", sourceServerID: UUID())
                )
            }
            try containerB.mainContext.save()
        }

        let reader = try SharedModelContainer.make(storeURL: storeURL)
        let all = try reader.mainContext.fetch(FetchDescriptor<AgentInboxItem>())
        XCTAssertEqual(all.count, 10)

        let buildPredicate = #Predicate<AgentInboxItem> { $0.group == "build" }
        let buildItems = try reader.mainContext.fetch(FetchDescriptor<AgentInboxItem>(predicate: buildPredicate))
        XCTAssertEqual(buildItems.count, 5)

        let alertsPredicate = #Predicate<AgentInboxItem> { $0.group == "alerts" }
        let alerts = try reader.mainContext.fetch(FetchDescriptor<AgentInboxItem>(predicate: alertsPredicate))
        XCTAssertEqual(alerts.count, 5)
    }
}
