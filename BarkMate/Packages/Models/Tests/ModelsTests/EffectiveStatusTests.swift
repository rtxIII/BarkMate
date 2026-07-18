import XCTest
import SwiftData
@testable import Models

final class EffectiveStatusTests: XCTestCase {

    private func makeTask(status: AgentStatus, updatedAt: Date) -> AgentTask {
        AgentTask(
            aggregateKey: "a::_",
            agentID: "a",
            displayName: "Task",
            status: status,
            updatedAt: updatedAt
        )
    }

    func testRunningPastThresholdBecomesStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .running, updatedAt: Date(timeIntervalSince1970: 10_000 - 1801))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), .stale)
    }

    func testRunningWithinThresholdStaysRunning() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .running, updatedAt: Date(timeIntervalSince1970: 10_000 - 1799))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), .running)
    }

    func testExactlyAtThresholdIsNotStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .running, updatedAt: Date(timeIntervalSince1970: 10_000 - 1800))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), .running)
    }

    func testNonRunningIsNeverStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let old = Date(timeIntervalSince1970: 0)
        for status in [AgentStatus.waitingInput, .blocked, .done, .failed] {
            let task = makeTask(status: status, updatedAt: old)
            XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), status)
        }
    }

    func testOffNeverStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .running, updatedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .off), .running)
    }
}
