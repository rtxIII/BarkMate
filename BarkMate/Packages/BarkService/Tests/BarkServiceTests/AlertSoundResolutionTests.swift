import XCTest
import Store
@testable import BarkService

final class AlertSoundResolutionTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "AlertSoundResolutionTests-\(UUID().uuidString)"
        guard let d = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        defaults = d
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil; suiteName = nil
    }

    private func userInfo(status: String?) -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = ["aps": ["alert": ["body": "hi"]]]
        if let status { info["agent_status"] = status }
        return info
    }

    func testUnconfiguredKeepsSenderSound() {
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: "failed"), defaults: defaults
        )
        XCTAssertEqual(decision, .keep)
    }

    func testNoStatusKeepsSenderSound() {
        let store = AlertSoundStore(defaults: defaults)
        store.setGlobalDefault(id: "bell")
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: nil), defaults: defaults
        )
        XCTAssertEqual(decision, .keep)
    }

    func testGlobalDefaultAppliesNamedSound() {
        let store = AlertSoundStore(defaults: defaults)
        store.setGlobalDefault(id: "bell")
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: "blocked"), defaults: defaults
        )
        XCTAssertEqual(decision, .named("bell.caf"))
    }

    func testPerStatusOverride() {
        let store = AlertSoundStore(defaults: defaults)
        store.setGlobalDefault(id: "bell")
        store.setOverride(id: "alarm", for: .failed)
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: "failed"), defaults: defaults
        )
        XCTAssertEqual(decision, .named("alarm.caf"))
    }

    func testSilenceDecision() {
        let store = AlertSoundStore(defaults: defaults)
        store.setGlobalDefault(id: "silence")
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: "blocked"), defaults: defaults
        )
        XCTAssertEqual(decision, .silence)
    }

    func testSystemDefaultKeepsSenderSound() {
        let store = AlertSoundStore(defaults: defaults)
        store.setGlobalDefault(id: SoundCatalog.systemDefaultID)
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: "blocked"), defaults: defaults
        )
        XCTAssertEqual(decision, .keep)
    }
}
