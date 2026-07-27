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
            [.off, .minutes(10), .minutes(15), .minutes(30), .minutes(60), .minutes(120)]
        )
    }

    func testCatalogDefault() {
        XCTAssertEqual(StaleThresholdCatalog.defaultThreshold, .minutes(15))
    }

    /// 默认值必须是 picker 可选档位,否则 Settings 里会成为选不出的孤值。
    func testCatalogDefaultIsSelectable() {
        XCTAssertTrue(StaleThresholdCatalog.options.contains(StaleThresholdCatalog.defaultThreshold))
    }
}
