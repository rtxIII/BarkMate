import XCTest
@testable import Models

final class StaleThresholdTests: XCTestCase {

    func testSecondsMapping() {
        XCTAssertNil(StaleThreshold.off.seconds)
        XCTAssertEqual(StaleThreshold.minutes(30).seconds, 1800)
        XCTAssertEqual(StaleThreshold.minutes(10).seconds, 600)
    }

    func testDisplayLabel() {
        XCTAssertEqual(StaleThreshold.off.displayLabel, "off")
        XCTAssertEqual(StaleThreshold.minutes(30).displayLabel, "30 min")
        XCTAssertEqual(StaleThreshold.minutes(120).displayLabel, "120 min")
    }

    func testCatalogOptions() {
        XCTAssertEqual(
            StaleThresholdCatalog.options,
            [.off, .minutes(10), .minutes(30), .minutes(60), .minutes(120)]
        )
    }

    func testCatalogDefault() {
        XCTAssertEqual(StaleThresholdCatalog.defaultThreshold, .minutes(30))
    }
}
