import XCTest
import SwiftData
@testable import BarkService
import Models
import Store

final class SearchEngineTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    // 时间戳常量：方便断言顺序。
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_001_000)
    private let t2 = Date(timeIntervalSince1970: 1_700_002_000)
    private let t4 = Date(timeIntervalSince1970: 1_700_004_000)

    override func setUpWithError() throws {
        container = try SharedModelContainer.makeInMemory()
        context = ModelContext(container)
        try seed()
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - Fixtures

    /// 4 条 fixture：
    /// - taskA (ci/build-1, running, "Deploy v1") @ t0
    /// - step1 (taskA, "started compile", body "compile src/...") @ t1
    /// - taskB (monitoring/_, blocked, "CPU 高 alert") @ t2
    /// - inboxIncoming (group "legacy", body "TODO refactor auth") @ t4
    private func seed() throws {
        let taskA = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "ci", taskID: "build-1"),
            agentID: "ci",
            taskID: "build-1",
            displayName: "Deploy v1",
            status: .running,
            latestStepTitle: "started compile",
            createdAt: t0,
            updatedAt: t0
        )
        context.insert(taskA)

        let step1 = AgentStep(
            task: taskA,
            status: .running,
            title: "started compile",
            body: "compile src/main.swift",
            createdAt: t1
        )
        context.insert(step1)
        taskA.steps.append(step1)

        let taskB = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "monitoring", taskID: nil),
            agentID: "monitoring",
            displayName: "CPU 高 alert",
            status: .blocked,
            createdAt: t2,
            updatedAt: t2
        )
        context.insert(taskB)

        let inboxIncoming = AgentInboxItem(
            title: "Legacy push",
            body: "TODO refactor auth",
            group: "legacy",
            createdAt: t4,
            updatedAt: t4
        )
        context.insert(inboxIncoming)

        try context.save()
    }

    // MARK: - Empty query

    func testEmptyQueryReturnsAllAcrossScopes() throws {
        let results = try SearchEngine.search(SearchQuery(), in: context)
        // 2 tasks + 1 step (taskA 命中后 step 被去重) + 1 inbox = 3
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.first?.updatedAt, t4) // inboxIncoming 最新
    }

    func testEmptyQueryWithScopeStepsOnly() throws {
        let results = try SearchEngine.search(
            SearchQuery(scope: .steps),
            in: context
        )
        XCTAssertEqual(results.count, 1)
        if case .step(let step) = results.first {
            XCTAssertEqual(step.body, "compile src/main.swift")
        } else {
            XCTFail("expected step result")
        }
    }

    // MARK: - Text search

    func testTextHitsAgentDisplayName() throws {
        let results = try SearchEngine.search(SearchQuery(text: "Deploy"), in: context)
        XCTAssertEqual(results.count, 1)
        if case .agent(let task) = results.first {
            XCTAssertEqual(task.displayName, "Deploy v1")
        } else {
            XCTFail("expected agent result")
        }
    }

    func testTextHitsInboxBody() throws {
        let results = try SearchEngine.search(SearchQuery(text: "refactor"), in: context)
        XCTAssertEqual(results.count, 1)
        if case .inbox(let item) = results.first {
            XCTAssertEqual(item.title, "Legacy push")
        } else {
            XCTFail("expected inbox result")
        }
    }

    func testTextHitsStepWhenAgentDoesNotMatch() throws {
        let results = try SearchEngine.search(SearchQuery(text: "compile"), in: context)
        // taskA 的 latestStepTitle="started compile" 也命中 → 优先返回 task，step 去重
        XCTAssertEqual(results.count, 1)
        if case .agent(let task) = results.first {
            XCTAssertEqual(task.displayName, "Deploy v1")
        } else {
            XCTFail("expected agent result")
        }
    }

    func testTextHitsStepBodyOnlyWhenAgentExcluded() throws {
        let results = try SearchEngine.search(
            SearchQuery(text: "main.swift", scope: .steps),
            in: context
        )
        XCTAssertEqual(results.count, 1)
        if case .step(let step) = results.first {
            XCTAssertEqual(step.body, "compile src/main.swift")
        } else {
            XCTFail("expected step result")
        }
    }

    func testTextSearchCaseInsensitive() throws {
        let results = try SearchEngine.search(SearchQuery(text: "DEPLOY"), in: context)
        XCTAssertEqual(results.count, 1)
    }

    func testTextSearchChinese() throws {
        let results = try SearchEngine.search(SearchQuery(text: "高"), in: context)
        XCTAssertEqual(results.count, 1)
        if case .agent(let task) = results.first {
            XCTAssertEqual(task.agentID, "monitoring")
        } else {
            XCTFail("expected agent result for 高")
        }
    }

    // MARK: - Scope

    func testScopeAgentsOnly() throws {
        let results = try SearchEngine.search(
            SearchQuery(scope: .agents),
            in: context
        )
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy {
            if case .agent = $0 { return true } else { return false }
        })
    }

    // MARK: - Status filter

    func testStatusFilterBlockedReturnsTaskAndSubsetSteps() throws {
        // fixtures: taskA=running, taskB=blocked → 仅 taskB 命中 agent; step1=running 被排除。
        let results = try SearchEngine.search(
            SearchQuery(scope: [.agents, .steps], statuses: [.blocked]),
            in: context
        )
        XCTAssertEqual(results.count, 1)
        guard case .agent(let task) = results.first else {
            return XCTFail("expected agent result, got \(String(describing: results.first))")
        }
        XCTAssertEqual(task.status, .blocked)
    }

    func testStatusFilterExcludesInbox() throws {
        // statuses 非空 → inbox 整表排除(它们无 status 概念)。
        let results = try SearchEngine.search(
            SearchQuery(scope: .all, statuses: [.running]),
            in: context
        )
        XCTAssertTrue(results.allSatisfy {
            if case .inbox = $0 { return false } else { return true }
        })
    }

    func testScopeInboxOnly() throws {
        let results = try SearchEngine.search(
            SearchQuery(scope: .inbox),
            in: context
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.allSatisfy {
            if case .inbox = $0 { return true } else { return false }
        })
    }

    func testScopeCombination() throws {
        let results = try SearchEngine.search(
            SearchQuery(scope: [.agents, .inbox]),
            in: context
        )
        // 2 tasks + 1 inbox
        XCTAssertEqual(results.count, 3)
    }

    // MARK: - AgentID filter

    func testAgentIDFilterMatchesTask() throws {
        let results = try SearchEngine.search(
            SearchQuery(agentIDs: ["ci"]),
            in: context
        )
        // taskA (agentID=ci) 命中，step 被去重
        XCTAssertEqual(results.count, 1)
        if case .agent(let task) = results.first {
            XCTAssertEqual(task.agentID, "ci")
        } else {
            XCTFail("expected agent ci")
        }
    }

    func testAgentIDFilterMatchesInboxGroup() throws {
        let results = try SearchEngine.search(
            SearchQuery(agentIDs: ["legacy"]),
            in: context
        )
        XCTAssertEqual(results.count, 1)
        if case .inbox(let item) = results.first {
            XCTAssertEqual(item.group, "legacy")
        } else {
            XCTFail("expected inbox with group=legacy")
        }
    }

    // MARK: - Date range

    func testDateRangeFilter() throws {
        // 仅命中 t2 (taskB)
        let from = Date(timeIntervalSince1970: 1_700_001_500)
        let to = Date(timeIntervalSince1970: 1_700_003_500)
        let results = try SearchEngine.search(
            SearchQuery(dateRange: from...to),
            in: context
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].updatedAt, t2)
    }

    // MARK: - Archived

    func testArchivedExcludedByDefault() throws {
        let taskC = AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: "old", taskID: "x"),
            agentID: "old",
            taskID: "x",
            displayName: "archived agent",
            status: .done,
            isArchived: true,
            createdAt: t0,
            updatedAt: t0
        )
        context.insert(taskC)
        try context.save()

        let results = try SearchEngine.search(
            SearchQuery(text: "archived"),
            in: context
        )
        XCTAssertEqual(results.count, 0)

        let withArchived = try SearchEngine.search(
            SearchQuery(text: "archived", includeArchived: true),
            in: context
        )
        XCTAssertEqual(withArchived.count, 1)
    }

    // MARK: - Sorting & limit

    func testResultsSortedByUpdatedAtDESC() throws {
        let results = try SearchEngine.search(SearchQuery(), in: context)
        let timestamps = results.map(\.updatedAt)
        XCTAssertEqual(timestamps, timestamps.sorted(by: >))
    }

    func testLimitTruncates() throws {
        let results = try SearchEngine.search(SearchQuery(), in: context, limit: 2)
        XCTAssertEqual(results.count, 2)
        // 应保留最新的两条:t4 (inboxIncoming) 和 t2 (taskB)
        XCTAssertEqual(results[0].updatedAt, t4)
        XCTAssertEqual(results[1].updatedAt, t2)
    }

    // MARK: - Facets

    func testAvailableFacets() throws {
        let facets = try SearchEngine.availableFacets(in: context)
        XCTAssertEqual(Set(facets.agentIDs), ["ci", "monitoring", "legacy"])
    }
}
