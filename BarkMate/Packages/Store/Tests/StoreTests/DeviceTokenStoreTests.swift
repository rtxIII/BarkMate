import XCTest
@testable import Store

final class DeviceTokenStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: DeviceTokenStore!

    override func setUpWithError() throws {
        suiteName = "DeviceTokenStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        self.defaults = defaults
        store = DeviceTokenStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
    }

    func testEmptyTokenReturnsNil() {
        XCTAssertNil(store.token())
    }

    func testSaveAndReadToken() {
        store.save(token: "apns-token")

        XCTAssertEqual(store.token(), "apns-token")
    }

    func testClearRemovesToken() {
        store.save(token: "apns-token")

        store.clear()

        XCTAssertNil(store.token())
    }
}
