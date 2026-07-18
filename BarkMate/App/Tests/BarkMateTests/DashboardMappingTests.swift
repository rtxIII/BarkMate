import XCTest
@testable import BarkAgent
import Models
import DesignSystem

@MainActor
final class DashboardMappingTests: XCTestCase {

    func testAgentCardDataMapsTaskFieldsAndProgress() {
        let task = AgentTask(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            aggregateKey: AgentTask.aggregateKey(agentID: "codex", taskID: "unit-tests"),
            agentID: "codex",
            taskID: "unit-tests",
            displayName: "codex-unit-tests",
            status: .running,
            latestStepTitle: "Writing tests",
            progress: "3/6",
            eta: Date(timeIntervalSinceNow: 25 * 60 + 30),
            isPinned: true,
            isMuted: true,
            updatedAt: Date(timeIntervalSinceNow: -5 * 60)
        )

        let data = AgentCardData.fromTask(task)

        XCTAssertEqual(data.id, task.id)
        XCTAssertEqual(data.agentName, "codex-unit-tests")
        XCTAssertEqual(data.taskID, "unit-tests")
        XCTAssertEqual(data.status, AgentStatus.running)
        XCTAssertEqual(data.latestStep, "Writing tests")
        XCTAssertEqual(data.progressLabel, "3/6")
        XCTAssertEqual(data.progressFraction, 0.5)
        XCTAssertEqual(data.etaLabel, "25m")
        XCTAssertEqual(data.updatedLabel, "5m")
        XCTAssertTrue(data.isPinned)
        XCTAssertTrue(data.isMuted)
    }

    func testProgressFractionSupportsRatiosPercentagesAndInvalidValues() {
        XCTAssertEqual(AgentCardData.progressFraction(from: "2/4"), 0.5)
        XCTAssertEqual(AgentCardData.progressFraction(from: " 3 / 2 "), 1.0)
        XCTAssertEqual(AgentCardData.progressFraction(from: "75%"), 0.75)
        XCTAssertEqual(AgentCardData.progressFraction(from: "125%"), 1.0)
        XCTAssertNil(AgentCardData.progressFraction(from: "3/0"))
        XCTAssertNil(AgentCardData.progressFraction(from: "half"))
        XCTAssertNil(AgentCardData.progressFraction(from: nil))
    }

    func testHistoryItemDataMapsTerminalAgentTasksToBadges() {
        let done = makeTask(displayName: "Done task", status: .done, latestStepTitle: "Finished")
        let failed = makeTask(displayName: "Failed task", status: .failed, latestStepTitle: "Broken")
        let stale = makeTask(displayName: "Stale task", status: .stale, latestStepTitle: nil)

        let doneItem = HistoryItemData.fromTask(done)
        let failedItem = HistoryItemData.fromTask(failed)
        let staleItem = HistoryItemData.fromTask(stale)

        XCTAssertEqual(doneItem.kind, HistoryItemKind.agent)
        XCTAssertEqual(doneItem.kindBadge, "agt-done")
        XCTAssertEqual(doneItem.body, "Finished")
        XCTAssertEqual(failedItem.kind, HistoryItemKind.agent)
        XCTAssertEqual(failedItem.kindBadge, "agt-fail")
        XCTAssertEqual(failedItem.body, "Broken")
        XCTAssertEqual(staleItem.kind, HistoryItemKind.stale)
        XCTAssertEqual(staleItem.kindBadge, "stale")
        XCTAssertEqual(staleItem.body, "Completed agent task")
    }

    func testHistoryItemDataMapsLegacyInboxPush() {
        let inbox = AgentInboxItem(
            title: nil,
            body: "legacy push body",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        let item = HistoryItemData.fromInboxItem(inbox)

        XCTAssertEqual(item.kind, HistoryItemKind.incoming)
        XCTAssertEqual(item.kindBadge, "bark")
        XCTAssertEqual(item.title, "Push")
        XCTAssertEqual(item.body, "legacy push body")
        XCTAssertEqual(item.updatedAt.timeIntervalSince1970, 1_000)
    }

    private func makeTask(
        displayName: String,
        status: AgentStatus,
        latestStepTitle: String?
    ) -> AgentTask {
        let agentID = displayName.lowercased().replacingOccurrences(of: " ", with: "-")
        return AgentTask(
            aggregateKey: AgentTask.aggregateKey(agentID: agentID, taskID: nil),
            agentID: agentID,
            displayName: displayName,
            status: status,
            latestStepTitle: latestStepTitle
        )
    }
}
