import XCTest

@MainActor
final class BarkMateRemoteNotificationTests: XCTestCase {

    private let runningTitle = "Simulator Push Running"
    private let waitingTitle = "Simulator Push Waiting"
    private let doneTitle = "Simulator Push Done"
    private let foregroundTitle = "Simulator Push Foreground"
    private let backgroundTitle = "Simulator Push Background"
    private let terminatedTitle = "Simulator Push Terminated"
    private let legacyTitle = "Simulator Push Legacy"
    private let encryptedTitle = "Simulator Push Encrypted"
    private let decryptionFailureBody = "Decryption Failed"
    private let remotePushWaitTimeout: TimeInterval = 20
    private let backgroundDeliveryWaitInterval: TimeInterval = 25
    private let terminatedDeliveryWaitInterval: TimeInterval = 60
    private let hostSynchronizationInterval: TimeInterval = 2

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testNotificationPermissionCanBeGranted() throws {
        try requireRemotePushE2E()

        app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowNotificationsButton = springboard.buttons["Allow"]
        if allowNotificationsButton.waitForExistence(timeout: 5) {
            allowNotificationsButton.tap()
        }

        XCTAssertTrue(app.buttons["tab-settings"].waitForExistence(timeout: 5), app.debugDescription)
    }

    func testRemoteNotificationRunningStageAppearsOnceOnDashboard() throws {
        try requireRemotePushE2E()
        let remotePushTask = launchDashboardAndFindRemoteTask(title: runningTitle)

        XCTAssertEqual(remotePushTask.count, 1, app.debugDescription)
        XCTAssertTrue(app.staticTexts["01 running"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["33%"].exists, app.debugDescription)
    }

    func testRemoteNotificationWaitingStageMovesSameTaskToNeedsYou() throws {
        try requireRemotePushE2E()
        let remotePushTask = launchDashboardAndFindRemoteTask(title: waitingTitle)

        XCTAssertEqual(remotePushTask.count, 1, app.debugDescription)
        XCTAssertTrue(app.staticTexts["NEEDS YOU"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["01 wait"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["[ WAIT ]"].exists, app.debugDescription)
    }

    func testRemoteNotificationDoneStageMovesSameTaskToSettledWithAllSteps() throws {
        try requireRemotePushE2E()
        let remotePushTask = launchDashboardAndFindRemoteTask(title: doneTitle)

        XCTAssertEqual(remotePushTask.count, 1, app.debugDescription)
        XCTAssertTrue(app.staticTexts["SETTLED"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["01 done"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["DONE"].exists, app.debugDescription)

        remotePushTask.firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Dossier"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.staticTexts["03 PUSHES"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts[runningTitle].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts[waitingTitle].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts[doneTitle].exists, app.debugDescription)
    }

    func testRemoteNotificationRefreshesDashboardWhileAppIsForeground() throws {
        try requireRemotePushE2E()

        app = XCUIApplication()
        app.launch()

        let agentsTab = app.buttons["tab-agents"]
        XCTAssertTrue(agentsTab.waitForExistence(timeout: 5), app.debugDescription)
        agentsTab.tap()
        XCTAssertEqual(app.state, .runningForeground)

        let remotePushTask = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", foregroundTitle)
        )
        XCTAssertTrue(
            remotePushTask.firstMatch.waitForExistence(timeout: remotePushWaitTimeout),
            app.debugDescription
        )
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertEqual(remotePushTask.count, 1, app.debugDescription)
        XCTAssertTrue(app.staticTexts["01 running"].exists, app.debugDescription)
    }

    func testRemoteNotificationArchivesWhileBackgroundedAndRefreshesOnReturn() throws {
        try requireRemotePushE2E()

        app = XCUIApplication()
        app.launch()

        let agentsTab = app.buttons["tab-agents"]
        XCTAssertTrue(agentsTab.waitForExistence(timeout: 5), app.debugDescription)
        agentsTab.tap()

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5), app.debugDescription)

        Thread.sleep(forTimeInterval: backgroundDeliveryWaitInterval)

        app.activate()
        XCTAssertTrue(agentsTab.waitForExistence(timeout: 5), app.debugDescription)

        let remotePushTask = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", backgroundTitle)
        )
        XCTAssertTrue(remotePushTask.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(remotePushTask.count, 1, app.debugDescription)
        XCTAssertTrue(app.staticTexts["01 running"].exists, app.debugDescription)
    }

    func testRemoteNotificationArchivesWhileTerminatedAndAppearsAfterLaunch() throws {
        try requireRemotePushE2E()

        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["tab-agents"].waitForExistence(timeout: 5), app.debugDescription)
        Thread.sleep(forTimeInterval: hostSynchronizationInterval)

        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5), app.debugDescription)
        Thread.sleep(forTimeInterval: terminatedDeliveryWaitInterval)

        app.launch()
        let agentsTab = app.buttons["tab-agents"]
        XCTAssertTrue(agentsTab.waitForExistence(timeout: 5), app.debugDescription)
        agentsTab.tap()

        let remotePushTask = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", terminatedTitle)
        )
        XCTAssertTrue(remotePushTask.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(remotePushTask.count, 1, app.debugDescription)
        XCTAssertTrue(app.staticTexts["01 running"].exists, app.debugDescription)
    }

    func testLegacyRemoteNotificationAppearsInIncomingHistory() throws {
        try requireRemotePushE2E()

        app = XCUIApplication()
        app.launch()

        let historyTab = app.buttons["tab-history"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5), app.debugDescription)
        historyTab.tap()
        XCTAssertTrue(app.buttons["history-filter-incoming"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["history-filter-incoming"].tap()

        XCTAssertTrue(app.staticTexts[legacyTitle].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Legacy Bark notification archived through real APNs."].exists)
    }

    func testEncryptedRemoteNotificationDecryptsIntoDashboardTask() throws {
        try requireRemotePushE2E()
        let remotePushTask = launchDashboardAndFindRemoteTask(title: encryptedTitle)

        XCTAssertEqual(remotePushTask.count, 1, app.debugDescription)
        XCTAssertTrue(app.staticTexts["01 running"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["50%"].exists, app.debugDescription)
    }

    func testEncryptedRemoteNotificationWithoutKeyFallsBackToIncomingHistory() throws {
        try requireRemotePushE2E()

        app = XCUIApplication()
        app.launch()

        let historyTab = app.buttons["tab-history"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5), app.debugDescription)
        historyTab.tap()
        XCTAssertTrue(app.buttons["history-filter-incoming"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["history-filter-incoming"].tap()

        let decryptionFailures = app.staticTexts.matching(
            NSPredicate(format: "label == %@", decryptionFailureBody)
        )
        XCTAssertTrue(
            decryptionFailures.firstMatch.waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertEqual(decryptionFailures.count, 1, app.debugDescription)
    }

    private func launchDashboardAndFindRemoteTask(title: String) -> XCUIElementQuery {
        app = XCUIApplication()
        app.launch()

        let agentsTab = app.buttons["tab-agents"]
        XCTAssertTrue(agentsTab.waitForExistence(timeout: 5), app.debugDescription)
        agentsTab.tap()

        let remotePushTask = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", title)
        )
        XCTAssertTrue(remotePushTask.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        return remotePushTask
    }

    private func requireRemotePushE2E() throws {
        #if BARKAGENT_REMOTE_PUSH_E2E
        return
        #else
        try XCTSkipUnless(
            false,
            "Run through scripts/test-simulator-remote-push.sh."
        )
        #endif
    }
}
