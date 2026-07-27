import XCTest
@testable import Store

final class OnboardingPrefsStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: OnboardingPrefsStore!

    override func setUpWithError() throws {
        suiteName = "OnboardingPrefsStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        self.defaults = defaults
        store = OnboardingPrefsStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        store = nil; defaults = nil; suiteName = nil
    }

    func testUnsetReturnsNotDismissed() {
        XCTAssertFalse(store.isEmptyStateHeroDismissed())
    }

    func testDismissPersists() {
        store.dismissEmptyStateHero()
        XCTAssertTrue(store.isEmptyStateHeroDismissed())
    }

    func testDismissPersistsAcrossInstances() {
        store.dismissEmptyStateHero()
        let reopened = OnboardingPrefsStore(defaults: defaults)
        XCTAssertTrue(reopened.isEmptyStateHeroDismissed())
    }
}
