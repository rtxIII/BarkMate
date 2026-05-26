import XCTest
@testable import BarkService
import Models

final class AgentRouterTests: XCTestCase {

    // MARK: - Memo path

    func testRouteWithoutAgentStatusGoesToIncomingMemo() {
        let parsed = ParsedPush(id: "msg-1", body: "legacy push")
        let route = AgentRouter.route(parsed)
        guard case .memo(let source) = route else {
            XCTFail("expected memo route, got \(route)")
            return
        }
        XCTAssertEqual(source, .incoming)
    }

    func testManualMemoSourceOverride() {
        let parsed = ParsedPush(id: "msg-2", body: "share extension")
        let route = AgentRouter.route(parsed, memoSource: .manual)
        guard case .memo(let source) = route else {
            XCTFail("expected memo route")
            return
        }
        XCTAssertEqual(source, .manual)
    }

    // MARK: - Agent path

    func testRouteWithAgentStatusGoesToAgent() {
        let parsed = ParsedPush(
            id: "msg-3",
            body: "running",
            group: "ci",
            agentStatus: .running,
            taskID: "build-1"
        )
        let route = AgentRouter.route(parsed)
        guard case .agent(let ctx) = route else {
            XCTFail("expected agent route")
            return
        }
        XCTAssertEqual(ctx.agentID, "ci")
        XCTAssertEqual(ctx.taskID, "build-1")
        XCTAssertEqual(ctx.status, .running)
        XCTAssertEqual(ctx.aggregateKey, "ci::build-1")
    }

    func testAggregateKeyUsesUnderscoreWhenTaskIDMissing() {
        let parsed = ParsedPush(
            id: "msg-4",
            body: "no task id",
            group: "monitoring",
            agentStatus: .blocked
        )
        let route = AgentRouter.route(parsed)
        guard case .agent(let ctx) = route else {
            XCTFail("expected agent route")
            return
        }
        XCTAssertNil(ctx.taskID)
        XCTAssertEqual(ctx.aggregateKey, "monitoring::_")
    }

    func testAggregateKeyUsesDefaultAgentIDWhenGroupMissing() {
        // group 缺省时 ParsedPush.agentID == "default"
        let parsed = ParsedPush(
            id: "msg-5",
            body: "no group",
            agentStatus: .done,
            taskID: "task-x"
        )
        let route = AgentRouter.route(parsed)
        guard case .agent(let ctx) = route else {
            XCTFail("expected agent route")
            return
        }
        XCTAssertEqual(ctx.agentID, "default")
        XCTAssertEqual(ctx.aggregateKey, "default::task-x")
    }

    func testAllAgentStatusValuesRoute() {
        for status in AgentStatus.allCases {
            let parsed = ParsedPush(
                id: "msg-\(status.rawValue)",
                body: "x",
                group: "g",
                agentStatus: status,
                taskID: "t"
            )
            let route = AgentRouter.route(parsed)
            guard case .agent(let ctx) = route else {
                XCTFail("\(status) should route to agent")
                return
            }
            XCTAssertEqual(ctx.status, status)
        }
    }

    // MARK: - Parser→Router seam (invalid agent_status string)

    func testInvalidAgentStatusStringFallsThroughToMemo() {
        // PushParser 会把无法识别的 agent_status 字符串解析为 nil
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["body": "x"]],
            "agent_status": "garbage_value",
            "group": "ci"
        ]
        let parsed = PushParser.parse(userInfo: userInfo)
        XCTAssertNil(parsed.agentStatus, "parser should drop invalid status string")

        let route = AgentRouter.route(parsed)
        guard case .memo(let source) = route else {
            XCTFail("invalid agent_status should fall to memo route")
            return
        }
        XCTAssertEqual(source, .incoming)
    }

    // MARK: - Group casing

    func testGroupTrimAndCasingPreserved() {
        // ParsedPush.agentID 会 trim 但不改 case
        let parsed = ParsedPush(
            id: "msg-6",
            body: "x",
            group: "  Mixed-Case  ",
            agentStatus: .running,
            taskID: "t"
        )
        let route = AgentRouter.route(parsed)
        guard case .agent(let ctx) = route else {
            XCTFail("expected agent route")
            return
        }
        XCTAssertEqual(ctx.agentID, "Mixed-Case")
        XCTAssertEqual(ctx.aggregateKey, "Mixed-Case::t")
    }
}
