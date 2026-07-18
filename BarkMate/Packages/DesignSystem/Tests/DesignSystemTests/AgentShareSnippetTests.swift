import XCTest
import Models
@testable import DesignSystem

final class AgentShareSnippetTests: XCTestCase {

    func testAgentCardShareTextIncludesStatusMetadataStepAndUpdatedLabel() {
        let data = AgentCardData(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            agentName: "codex-tests",
            taskID: "coverage-42",
            status: .waitingInput,
            latestStep: "Confirm test scope",
            progressLabel: "4/7",
            progressFraction: 4.0 / 7.0,
            etaLabel: nil,
            updatedLabel: "2m",
            isPinned: false,
            isMuted: false
        )

        XCTAssertEqual(
            AgentShareSnippet.text(from: data),
            """
            codex-tests · [ WAIT ]
            task: coverage-42 · 4/7
            “Confirm test scope”
            2m
            """
        )
    }

    func testAgentCardShareTextOmitsEmptyOptionalLines() {
        let data = AgentCardData(
            id: UUID(),
            agentName: "codex-tests",
            taskID: nil,
            status: .running,
            latestStep: "",
            progressLabel: nil,
            progressFraction: nil,
            etaLabel: nil,
            updatedLabel: "",
            isPinned: false,
            isMuted: false
        )

        XCTAssertEqual(AgentShareSnippet.text(from: data), "codex-tests · [ RUN ]")
    }

    func testDetailHeroShareTextIncludesEtaWhenPresent() {
        let data = DetailHeroData(
            status: .running,
            agentName: "codex-tests",
            taskID: "coverage-42",
            progressLabel: "4/7",
            etaLabel: "12m",
            updatedLabel: "now"
        )

        XCTAssertEqual(
            AgentShareSnippet.text(from: data),
            """
            codex-tests · [ RUN ]
            task: coverage-42 · 4/7
            eta 12m
            now
            """
        )
    }

    func testDetailHeroShareTextOmitsPlaceholderProgressAndEta() {
        let data = DetailHeroData(
            status: .done,
            agentName: "codex-tests",
            taskID: nil,
            progressLabel: "—",
            etaLabel: "—",
            updatedLabel: "1h"
        )

        XCTAssertEqual(
            AgentShareSnippet.text(from: data),
            """
            codex-tests · [ DONE ]
            1h
            """
        )
    }
}
