import XCTest
import Models
@testable import Store

final class AlertSoundStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: AlertSoundStore!

    override func setUpWithError() throws {
        suiteName = "AlertSoundStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        self.defaults = defaults
        store = AlertSoundStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        store = nil; defaults = nil; suiteName = nil
    }

    func testEmptyResolvesToNil() {
        XCTAssertNil(store.resolvedSoundID(for: .failed))
        XCTAssertNil(store.globalDefaultID())
    }

    func testGlobalDefaultRoundTrip() {
        store.setGlobalDefault(id: "bell")
        XCTAssertEqual(store.globalDefaultID(), "bell")
    }

    func testResolveFallsBackToGlobalDefault() {
        store.setGlobalDefault(id: "chime")
        XCTAssertEqual(store.resolvedSoundID(for: .blocked), "chime")
    }

    func testPerStatusOverrideWinsOverGlobal() {
        store.setGlobalDefault(id: "chime")
        store.setOverride(id: "alarm", for: .failed)
        XCTAssertEqual(store.resolvedSoundID(for: .failed), "alarm")
        XCTAssertEqual(store.resolvedSoundID(for: .blocked), "chime")
    }

    func testClearOverrideFallsBackToGlobal() {
        store.setGlobalDefault(id: "chime")
        store.setOverride(id: "alarm", for: .failed)
        store.setOverride(id: nil, for: .failed)
        XCTAssertNil(store.overrideID(for: .failed))
        XCTAssertEqual(store.resolvedSoundID(for: .failed), "chime")
    }

    func testOverridableStatuses() {
        XCTAssertEqual(
            AlertSoundStore.overridableStatuses,
            [.waitingInput, .blocked, .failed]
        )
    }
}
