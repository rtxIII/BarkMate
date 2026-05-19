import XCTest
@testable import Store

final class DraftManagerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var manager: DraftManager!
    private let suiteName = "DraftManagerTests-\(UUID().uuidString)"

    override func setUpWithError() throws {
        guard let suite = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        defaults = suite
        manager = DraftManager(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testLoadEmptyReturnsNil() {
        XCTAssertNil(manager.load())
    }

    func testSaveAndLoadRoundTrip() {
        let draft = DraftManager.Draft(body: "hello", title: "t", updatedAt: Date(timeIntervalSince1970: 1_000_000))
        manager.save(draft)

        let loaded = manager.load()
        XCTAssertEqual(loaded?.body, "hello")
        XCTAssertEqual(loaded?.title, "t")
        XCTAssertEqual(loaded?.updatedAt.timeIntervalSince1970, 1_000_000)
    }

    func testClearRemovesDraft() {
        manager.save(DraftManager.Draft(body: "x"))
        XCTAssertNotNil(manager.load())
        manager.clear()
        XCTAssertNil(manager.load())
    }

    func testOverwritesPreviousDraft() {
        manager.save(DraftManager.Draft(body: "v1"))
        manager.save(DraftManager.Draft(body: "v2"))
        XCTAssertEqual(manager.load()?.body, "v2")
    }
}
