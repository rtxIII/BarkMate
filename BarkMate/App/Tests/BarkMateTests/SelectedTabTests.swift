import XCTest
@testable import BarkAgent

@MainActor
final class SelectedTabTests: XCTestCase {

    func testRequestSetupGuideSwitchesToSettingsAndStoresDeepLink() {
        let selectedTab = SelectedTab()

        selectedTab.requestSetupGuide()

        XCTAssertEqual(selectedTab.current, .settings)
        XCTAssertEqual(selectedTab.pendingDeepLink, .setupGuide)
    }
}
