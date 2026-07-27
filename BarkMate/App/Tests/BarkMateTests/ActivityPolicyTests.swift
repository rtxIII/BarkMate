import XCTest
@testable import BarkAgent
import Models

final class ActivityPolicyTests: XCTestCase {

    private func snap(
        _ id: String,
        _ status: AgentStatus,
        archived: Bool = false,
        hasActivity: Bool = false,
        ago: TimeInterval = 0
    ) -> ActivityPolicy.TaskSnapshot {
        ActivityPolicy.TaskSnapshot(
            id: UUID(uuidString: id)!,
            status: status,
            isArchived: archived,
            updatedAt: Date(timeIntervalSinceNow: -ago),
            hasActivity: hasActivity
        )
    }

    private func uuid(_ n: Int) -> UUID {
        UUID(uuidString: "0000000\(n)-0000-0000-0000-000000000000")!
    }
    private func snapN(_ n: Int, _ status: AgentStatus, hasActivity: Bool = false, ago: TimeInterval = 0) -> ActivityPolicy.TaskSnapshot {
        ActivityPolicy.TaskSnapshot(id: uuid(n), status: status, isArchived: false, updatedAt: Date(timeIntervalSinceNow: -ago), hasActivity: hasActivity)
    }

    // MARK: - 状态映射:只有 waiting_input / blocked 属 needsYou

    func testNeedsYouMapping() {
        XCTAssertTrue(ActivityPolicy.isNeedsYou(.waitingInput))
        XCTAssertTrue(ActivityPolicy.isNeedsYou(.blocked))
        XCTAssertFalse(ActivityPolicy.isNeedsYou(.running))
        XCTAssertFalse(ActivityPolicy.isNeedsYou(.done))
        XCTAssertFalse(ActivityPolicy.isNeedsYou(.failed))
        XCTAssertFalse(ActivityPolicy.isNeedsYou(.stale))
    }

    // MARK: - start:needsYou 且无 LA → start

    func testStartsForNeedsYouWithoutActivity() {
        let plan = ActivityPolicy.plan(tasks: [snapN(1, .waitingInput), snapN(2, .blocked)])
        XCTAssertEqual(Set(plan.toStart), [uuid(1), uuid(2)])
        XCTAssertTrue(plan.toEnd.isEmpty)
        XCTAssertTrue(plan.toUpdate.isEmpty)
    }

    func testDoesNotStartForRunningOrDone() {
        let plan = ActivityPolicy.plan(tasks: [snapN(1, .running), snapN(2, .done), snapN(3, .failed)])
        XCTAssertTrue(plan.toStart.isEmpty)
        XCTAssertTrue(plan.toEnd.isEmpty)
        XCTAssertTrue(plan.toUpdate.isEmpty)
    }

    // MARK: - end:有 LA 但离开 needsYou / 归档 → end

    func testEndsWhenLeavesNeedsYou() {
        // 之前 waiting(起了 LA),现在 running → end
        let plan = ActivityPolicy.plan(tasks: [snapN(1, .running, hasActivity: true)])
        XCTAssertEqual(plan.toEnd, [uuid(1)])
        XCTAssertTrue(plan.toStart.isEmpty)
        XCTAssertTrue(plan.toUpdate.isEmpty)
    }

    func testEndsWhenArchived() {
        let archived = ActivityPolicy.TaskSnapshot(id: uuid(1), status: .waitingInput, isArchived: true, updatedAt: Date(), hasActivity: true)
        let plan = ActivityPolicy.plan(tasks: [archived])
        XCTAssertEqual(plan.toEnd, [uuid(1)])
    }

    // MARK: - update:仍 needsYou 且已有 LA → update

    func testUpdatesWhenStaysNeedsYouWithActivity() {
        let plan = ActivityPolicy.plan(tasks: [snapN(1, .waitingInput, hasActivity: true)])
        XCTAssertEqual(plan.toUpdate, [uuid(1)])
        XCTAssertTrue(plan.toStart.isEmpty)
        XCTAssertTrue(plan.toEnd.isEmpty)
    }

    // MARK: - cap 4:第 5 个 needsYou 不 start

    func testCapAtMaxActive() {
        let tasks = (1...5).map { snapN($0, .waitingInput, ago: TimeInterval($0)) } // n=1 最新, n=5 最旧
        let plan = ActivityPolicy.plan(tasks: tasks)
        XCTAssertEqual(plan.toStart.count, ActivityPolicy.maxActive)
        // 最旧的 n=5 被 cap 挤出,不 start
        XCTAssertFalse(plan.toStart.contains(uuid(5)))
        XCTAssertTrue(plan.toStart.contains(uuid(1)))
    }

    // MARK: - LRU:新 needsYou 到来,挤掉最旧的已有 LA

    func testLRUEvictsOldestWhenNewerArrives() {
        // 4 个已有 LA(n=2..5,越大越旧),第 5 个更新的 n=1 无 LA 到来
        var tasks = (2...5).map { snapN($0, .waitingInput, hasActivity: true, ago: TimeInterval($0)) }
        tasks.append(snapN(1, .waitingInput, hasActivity: false, ago: 0)) // 最新
        let plan = ActivityPolicy.plan(tasks: tasks)
        // 最新的 n=1 起 LA
        XCTAssertEqual(plan.toStart, [uuid(1)])
        // 最旧的 n=5 被挤出 desired → end
        XCTAssertEqual(plan.toEnd, [uuid(5)])
        // 其余 3 个(n=2,3,4)保留 → update
        XCTAssertEqual(Set(plan.toUpdate), [uuid(2), uuid(3), uuid(4)])
    }
}
