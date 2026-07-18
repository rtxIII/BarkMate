import XCTest
import Models
@testable import Store

final class StaleTimeoutStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: StaleTimeoutStore!

    override func setUpWithError() throws {
        suiteName = "StaleTimeoutStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        self.defaults = defaults
        store = StaleTimeoutStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        store = nil; defaults = nil; suiteName = nil
    }

    func testUnsetReturnsDefault() {
        XCTAssertEqual(store.threshold(), StaleThresholdCatalog.defaultThreshold)
    }

    func testMinutesRoundTrip() {
        store.setThreshold(.minutes(60))
        XCTAssertEqual(store.threshold(), .minutes(60))
    }

    func testOffRoundTrip() {
        store.setThreshold(.off)
        XCTAssertEqual(store.threshold(), .off)
    }

    func testOverwriteThreshold() {
        store.setThreshold(.minutes(10))
        store.setThreshold(.minutes(120))
        XCTAssertEqual(store.threshold(), .minutes(120))
    }
}
