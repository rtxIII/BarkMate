import XCTest
@testable import Store

final class NotificationStatusStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: NotificationStatusStore!

    override func setUpWithError() throws {
        suiteName = "NotificationStatusStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        self.defaults = defaults
        store = NotificationStatusStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
    }

    func testCurrentDefaultsToUnknown() {
        let status = store.current()

        XCTAssertEqual(status.kind, .unknown)
        XCTAssertNil(status.detail)
        XCTAssertEqual(status.updatedAt, .distantPast)
    }

    func testSaveAndReadStatus() {
        let date = Date(timeIntervalSince1970: 1_234_567)

        store.save(NotificationStatus(
            kind: .serverUnreachable,
            detail: "registration failed",
            updatedAt: date
        ))

        XCTAssertEqual(store.current(), NotificationStatus(
            kind: .serverUnreachable,
            detail: "registration failed",
            updatedAt: date
        ))
    }

    func testSavingStatusWithoutDetailClearsPreviousDetail() {
        store.save(NotificationStatus(kind: .serverUnreachable, detail: "old detail"))

        store.save(NotificationStatus(kind: .ok, detail: nil))

        let status = store.current()
        XCTAssertEqual(status.kind, .ok)
        XCTAssertNil(status.detail)
    }

    func testSavePostsDidChangeNotification() {
        let expectation = expectation(forNotification: NotificationStatusStore.didChangeNotification, object: nil)

        store.save(NotificationStatus(kind: .ok))

        wait(for: [expectation], timeout: 1)
    }
}
