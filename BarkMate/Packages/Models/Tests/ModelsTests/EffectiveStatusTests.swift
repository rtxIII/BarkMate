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

    func testWaitingPastThresholdBecomesStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .waitingInput, updatedAt: Date(timeIntervalSince1970: 10_000 - 1801))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), .stale)
    }

    func testWaitingWithinThresholdStaysWaiting() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .waitingInput, updatedAt: Date(timeIntervalSince1970: 10_000 - 1799))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), .waitingInput)
    }

    func testNonAgingStatusesAreNeverStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let old = Date(timeIntervalSince1970: 0)
        // blocked / done / failed 不参与老化(running / waitingInput 才会,各自单测)。
        for status in [AgentStatus.blocked, .done, .failed] {
            let task = makeTask(status: status, updatedAt: old)
            XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), status)
        }
    }

    func testWaitingOffNeverStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .waitingInput, updatedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .off), .waitingInput)
    }

    func testOffNeverStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .running, updatedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .off), .running)
    }
}
