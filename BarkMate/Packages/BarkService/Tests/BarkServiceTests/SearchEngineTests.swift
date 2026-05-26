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
    private let t3 = Date(timeIntervalSince1970: 1_700_003_000)
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

    /// 5 条 fixture：
    /// - taskA (ci/build-1, running, "Deploy v1") @ t0
    /// - step1 (taskA, "started compile", body "compile src/...") @ t1
    /// - taskB (monitoring/_, blocked, "CPU 高 alert") @ t2
    /// - memoMeeting (manual, title "Meeting notes", body "discuss roadmap", tags [work]) @ t3
    /// - memoIncoming (incoming, group "legacy", body "TODO refactor #work") @ t4
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

        let memoMeeting = Memo(
            source: .manual,
            title: "Meeting notes",
            body: "discuss roadmap",
            tags: ["work"],
            createdAt: t3,
            updatedAt: t3
        )
        context.insert(memoMeeting)

        let memoIncoming = Memo(
            source: .incoming,
            body: "TODO refactor auth #work",
            tags: ["work", "refactor"],
            group: "legacy",
            createdAt: t4,
            updatedAt: t4
        )
        context.insert(memoIncoming)

        try context.save()
    }

    // MARK: - Empty query

    func testEmptyQueryReturnsAllAcrossScopes() throws {
        let results = try SearchEngine.search(SearchQuery(), in: context)
        // 2 tasks + 1 step (taskA 命中后 step 被去重) + 2 memos = ?
        // 注意：空 query 下 task 全部命中，step 因所属 taskA 已命中被去重
        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(results.first?.updatedAt, t4) // memoIncoming 最新
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

    func testTextHitsMemoBody() throws {
        let results = try SearchEngine.search(SearchQuery(text: "roadmap"), in: context)
        XCTAssertEqual(results.count, 1)
        if case .memo(let memo) = results.first {
            XCTAssertEqual(memo.title, "Meeting notes")
        } else {
            XCTFail("expected memo result")
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

    // MARK: - Status filter (Phase 4.11)

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

    func testStatusFilterExcludesMemos() throws {
        // statuses 非空 → memos 整表排除(它们无 status 概念)。
        let results = try SearchEngine.search(
            SearchQuery(scope: .all, statuses: [.running]),
            in: context
        )
        XCTAssertTrue(results.allSatisfy {
            if case .memo = $0 { return false } else { return true }
        })
    }

    func testScopeMemosOnly() throws {
        let results = try SearchEngine.search(
            SearchQuery(scope: .memos),
            in: context
        )
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy {
            if case .memo = $0 { return true } else { return false }
        })
    }

    func testScopeCombination() throws {
        let results = try SearchEngine.search(
            SearchQuery(scope: [.agents, .memos]),
            in: context
        )
        XCTAssertEqual(results.count, 4)
    }

    // MARK: - Tag filter

    func testTagFilterAppliesOnlyToMemos() throws {
        let results = try SearchEngine.search(
            SearchQuery(tags: ["work"]),
            in: context
        )
        // 仅 Memo 命中，AgentTask / AgentStep 因无 tags 字段被跳过
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy {
            if case .memo = $0 { return true } else { return false }
        })
    }

    func testTagFilterNoMatch() throws {
        let results = try SearchEngine.search(
            SearchQuery(tags: ["nonexistent"]),
            in: context
        )
        XCTAssertEqual(results.count, 0)
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

    func testAgentIDFilterMatchesMemoGroup() throws {
        let results = try SearchEngine.search(
            SearchQuery(agentIDs: ["legacy"]),
            in: context
        )
        XCTAssertEqual(results.count, 1)
        if case .memo(let memo) = results.first {
            XCTAssertEqual(memo.group, "legacy")
        } else {
            XCTFail("expected memo with group=legacy")
        }
    }

    // MARK: - Date range

    func testDateRangeFilter() throws {
        // 仅命中 t2 (taskB) 和 t3 (memoMeeting)
        let from = Date(timeIntervalSince1970: 1_700_001_500)
        let to = Date(timeIntervalSince1970: 1_700_003_500)
        let results = try SearchEngine.search(
            SearchQuery(dateRange: from...to),
            in: context
        )
        XCTAssertEqual(results.count, 2)
        // 排序按 updatedAt DESC：memoMeeting(t3) 在前，taskB(t2) 在后
        XCTAssertEqual(results[0].updatedAt, t3)
        XCTAssertEqual(results[1].updatedAt, t2)
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

    // MARK: - Combined

    func testCombinedTextAndScope() throws {
        let results = try SearchEngine.search(
            SearchQuery(text: "work", scope: .memos),
            in: context
        )
        // memoIncoming 的 body 含 "#work"，memoMeeting 的 tags 含 "work"
        XCTAssertEqual(results.count, 2)
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
        // 应保留最新的两条
        XCTAssertEqual(results[0].updatedAt, t4)
        XCTAssertEqual(results[1].updatedAt, t3)
    }

    // MARK: - Facets

    func testAvailableFacets() throws {
        let facets = try SearchEngine.availableFacets(in: context)
        XCTAssertEqual(Set(facets.tags), ["work", "refactor"])
        XCTAssertEqual(Set(facets.agentIDs), ["ci", "monitoring", "legacy"])
    }
}
