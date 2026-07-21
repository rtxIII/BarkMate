import XCTest

@MainActor
final class BarkMateFunctionalSmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testMainTabsNavigateToExpectedScreens() {
        launchApp()

        XCTAssertTrue(
            app.staticTexts["Send one push. Get one living card."].waitForExistence(timeout: 5),
            app.debugDescription
        )

        app.buttons["tab-history"].tap()
        XCTAssertTrue(app.staticTexts["History fills in once tasks finish or pushes arrive."].waitForExistence(timeout: 2))

        app.buttons["tab-search"].tap()
        XCTAssertTrue(app.staticTexts["Search agent cards, step history, and incoming pushes."].waitForExistence(timeout: 2))

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.staticTexts["Manage servers"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Auto-installed"].exists)
    }

    func testEdgeSwipePopsFromAgentDetail() {
        launchApp(seedScenario: "agent-detail")

        // 进入详情页(Dossier)。
        let card = app.staticTexts["Codex Coverage Probe"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), app.debugDescription)
        card.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Dossier"].waitForExistence(timeout: 3), app.debugDescription)

        // 从屏幕左边缘向右滑 —— 隐藏导航栏后仍应触发系统的边缘返回手势。
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        // 回到 Dashboard:Dossier 消失、卡片重新出现。
        XCTAssertTrue(card.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Dossier"].exists, app.debugDescription)
    }

    func testSettingsTimeSensitiveAlertsCanBeToggled() {
        launchApp()

        app.buttons["tab-settings"].tap()

        let timeSensitiveAlertsSwitch = app.switches["Time-Sensitive alerts"]
        XCTAssertTrue(timeSensitiveAlertsSwitch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(timeSensitiveAlertsSwitch.value as? String, "1")

        timeSensitiveAlertsSwitch.tap()
        XCTAssertEqual(timeSensitiveAlertsSwitch.value as? String, "0")

        timeSensitiveAlertsSwitch.tap()
        XCTAssertEqual(timeSensitiveAlertsSwitch.value as? String, "1")
    }

    func testSettingsContentCanScrollThroughAllSections() {
        launchApp()

        app.buttons["tab-settings"].tap()

        XCTAssertTrue(app.staticTexts["Stale timeout"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["30 MIN"].exists)
        XCTAssertTrue(app.staticTexts["Alert sound"].exists)
        XCTAssertTrue(app.staticTexts["DEFAULT"].exists)

        let barkProtocolReference = app.staticTexts["Bark protocol reference"]
        for _ in 0..<3 {
            if barkProtocolReference.isHittable { break }
            app.swipeUp()
        }

        XCTAssertTrue(app.staticTexts["Privacy policy"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["APNs token"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["Not yet registered"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["MISSING"].exists, app.debugDescription)
        XCTAssertTrue(barkProtocolReference.isHittable, app.debugDescription)
        XCTAssertTrue(app.buttons["tab-settings"].isHittable, app.debugDescription)
    }

    func testSettingsDisplaysServerAndRegisteredDeviceStates() {
        launchApp(
            seedScenario: "settings-statuses",
            deviceToken: "1234567890abcdef1234567890"
        )

        app.buttons["tab-settings"].tap()

        XCTAssertTrue(app.staticTexts["Online Settings Probe"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Offline Settings Probe"].exists)
        XCTAssertTrue(app.staticTexts["Pending Settings Probe"].exists)
        XCTAssertTrue(app.staticTexts["01 · APNS OK"].exists)
        XCTAssertTrue(app.staticTexts["ON"].exists)
        XCTAssertTrue(app.staticTexts["OFF"].exists)
        XCTAssertTrue(app.staticTexts["PENDING"].exists)

        let registeredDeviceState = app.staticTexts["REGISTERED"]
        for _ in 0..<3 {
            if registeredDeviceState.isHittable { break }
            app.swipeUp()
        }

        XCTAssertTrue(app.staticTexts["12345678…34567890"].exists, app.debugDescription)
        XCTAssertTrue(registeredDeviceState.isHittable, app.debugDescription)
    }

    func testSetupGuideCanSendDemoPushFromEmptyDashboard() {
        launchApp()

        XCTAssertTrue(app.buttons["dashboard-setup-guide"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["dashboard-setup-guide"].tap()

        XCTAssertTrue(app.buttons["setup-copy-install"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["setup-send-test-push"].exists)

        app.buttons["setup-copy-install"].tap()
        XCTAssertEqual(app.buttons["setup-copy-install"].label, "COPIED")

        app.buttons["setup-send-test-push"].tap()

        XCTAssertEqual(app.buttons["setup-send-test-push"].label, "SENT ✓")

        XCTAssertTrue(app.buttons["setup-copy-uninstall"].exists)
        app.buttons["setup-copy-uninstall"].tap()
        XCTAssertEqual(app.buttons["setup-copy-uninstall"].label, "COPIED")
    }

    func testDashboardCanSendDemoPushFromEmptyState() {
        launchApp()

        XCTAssertTrue(app.buttons["dashboard-send-demo-push"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["dashboard-send-demo-push"].tap()

        XCTAssertTrue(app.staticTexts["demo-agent"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.staticTexts["demo-task · Demo step 1"].exists)
    }

    func testDenseDashboardCountsAndSettledItemsRemainReachable() {
        launchApp(seedScenario: "dashboard-dense")

        XCTAssertTrue(app.staticTexts["Dense Wait Probe"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["— HEADS-UP / 07 AGENTS —"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["01 wait · 01 stuck"].exists)
        XCTAssertTrue(app.staticTexts["03 running"].exists)
        XCTAssertTrue(app.staticTexts["01 done · 01 fail"].exists)

        let failedSettledTask = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Dense Fail Probe"))
            .firstMatch
        for _ in 0..<5 {
            if failedSettledTask.isHittable { break }
            app.swipeUp()
        }

        XCTAssertTrue(app.staticTexts["Dense Done Probe"].exists, app.debugDescription)
        XCTAssertTrue(failedSettledTask.isHittable, app.debugDescription)
        XCTAssertTrue(app.buttons["tab-settings"].isHittable, app.debugDescription)
    }

    func testUnreachableStatusOpensSetupBannerAndServerList() {
        launchApp(
            seedScenario: "server-health",
            notificationStatusKind: "serverUnreachable",
            notificationStatusDetail: "Coverage server is down."
        )

        XCTAssertTrue(app.staticTexts["Server unreachable"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Coverage server is down."].exists)

        app.buttons["SERVERS"].tap()

        XCTAssertTrue(app.staticTexts["Refresh Probe"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.buttons["server-list-refresh"].exists)
    }

    func testAPNsRegistrationFailureOpensSetupBannerAndServerList() {
        launchApp(
            seedScenario: "server-health",
            notificationStatusKind: "apnsRegistrationFailed",
            notificationStatusDetail: "APNs registration failed for coverage."
        )

        XCTAssertTrue(app.staticTexts["APNs registration failed"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["APNs registration failed for coverage."].exists)

        app.buttons["SERVERS"].tap()

        XCTAssertTrue(app.staticTexts["Refresh Probe"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.buttons["server-list-refresh"].exists)
    }

    func testSetupGuideShowsAuthorizationDeniedBanner() {
        launchApp(
            notificationStatusKind: "authorizationDenied",
            notificationStatusDetail: "Notifications blocked for coverage."
        )

        XCTAssertTrue(app.staticTexts["Notifications are off"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Notifications blocked for coverage."].exists)
        XCTAssertTrue(app.buttons["OPEN"].exists)
    }

    func testSetupGuideShowsStorageUnavailableBanner() {
        launchApp(
            notificationStatusKind: "storageUnavailable",
            notificationStatusDetail: "Shared storage unavailable for coverage."
        )

        XCTAssertTrue(app.staticTexts["Storage unavailable"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Shared storage unavailable for coverage."].exists)
        XCTAssertTrue(app.buttons["HELP"].exists)
    }

    func testServerManagementCanAddLocalServer() {
        launchApp()

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-manage-servers"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["settings-manage-servers"].tap()
        XCTAssertTrue(app.buttons["server-list-add"].waitForExistence(timeout: 3), app.debugDescription)

        app.buttons["server-list-add"].tap()
        XCTAssertTrue(app.textFields["add-server-name"].waitForExistence(timeout: 2))

        app.textFields["add-server-name"].tap()
        app.textFields["add-server-name"].typeText("Local Smoke")

        app.textFields["add-server-address"].tap()
        app.textFields["add-server-address"].typeText("127.0.0.1:9999")

        app.buttons["add-server-save"].tap()

        XCTAssertTrue(app.staticTexts["Local Smoke"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["https://127.0.0.1:9999"].exists)
    }

    func testAddServerStartsDisabledAndCanCancel() {
        launchApp()

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-manage-servers"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["settings-manage-servers"].tap()
        XCTAssertTrue(app.buttons["server-list-add"].waitForExistence(timeout: 3), app.debugDescription)

        app.buttons["server-list-add"].tap()
        XCTAssertTrue(app.textFields["add-server-address"].waitForExistence(timeout: 2))

        XCTAssertFalse(app.buttons["add-server-save"].isEnabled)
        XCTAssertFalse(app.buttons["add-server-test-connection"].isEnabled)

        app.buttons["add-server-cancel"].tap()

        XCTAssertTrue(app.buttons["server-list-add"].waitForExistence(timeout: 2), app.debugDescription)
    }

    func testAddServerCanTestConnectionAndRegisterDeviceToken() {
        launchApp(barkClientMode: "success", deviceToken: "abcdef123456")

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-manage-servers"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["settings-manage-servers"].tap()
        XCTAssertTrue(app.buttons["server-list-add"].waitForExistence(timeout: 3), app.debugDescription)

        app.buttons["server-list-add"].tap()
        XCTAssertTrue(app.textFields["add-server-name"].waitForExistence(timeout: 2))

        app.textFields["add-server-name"].tap()
        app.textFields["add-server-name"].typeText("Registered Smoke")

        app.textFields["add-server-address"].tap()
        app.textFields["add-server-address"].typeText("registered.example.test")

        app.buttons["add-server-test-connection"].tap()
        XCTAssertTrue(
            app.buttons["add-server-test-connection"]
                .waitForExistence(timeout: 3),
            app.debugDescription
        )
        XCTAssertTrue(app.buttons["add-server-test-connection"].label.contains("OK"))

        app.buttons["add-server-save"].tap()

        XCTAssertTrue(app.staticTexts["Registered Smoke"].waitForExistence(timeout: 3))
        let lastCheck = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Last check:'")).firstMatch
        XCTAssertTrue(lastCheck.waitForExistence(timeout: 3), app.debugDescription)
    }

    func testAddServerShowsConnectionFailure() {
        launchApp(barkClientMode: "failure")

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-manage-servers"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["settings-manage-servers"].tap()
        XCTAssertTrue(app.buttons["server-list-add"].waitForExistence(timeout: 3), app.debugDescription)

        app.buttons["server-list-add"].tap()
        XCTAssertTrue(app.textFields["add-server-address"].waitForExistence(timeout: 2))

        app.textFields["add-server-address"].tap()
        app.textFields["add-server-address"].typeText("failing.example.test")

        app.buttons["add-server-test-connection"].tap()

        XCTAssertTrue(app.staticTexts["HTTP 503"].waitForExistence(timeout: 3), app.debugDescription)
    }

    func testServerRefreshUpdatesSeededServerHealth() {
        launchApp(seedScenario: "server-health", barkClientMode: "success")

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-manage-servers"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["settings-manage-servers"].tap()
        XCTAssertTrue(app.staticTexts["Refresh Probe"].waitForExistence(timeout: 3), app.debugDescription)

        app.buttons["server-list-refresh"].tap()

        let lastCheck = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Last check:'")).firstMatch
        XCTAssertTrue(lastCheck.waitForExistence(timeout: 3), app.debugDescription)
    }

    func testServerManagementCanDeleteSeededServer() {
        launchApp(seedScenario: "server-health")

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-manage-servers"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["settings-manage-servers"].tap()
        let server = app.staticTexts["Refresh Probe"]
        XCTAssertTrue(server.waitForExistence(timeout: 3), app.debugDescription)

        server.swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertFalse(server.waitForExistence(timeout: 1), app.debugDescription)
    }

    func testSettingsHeaderShortcutOpensServerList() {
        launchApp(seedScenario: "server-health")

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-server-list-shortcut"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["settings-server-list-shortcut"].tap()

        XCTAssertTrue(app.staticTexts["Refresh Probe"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.buttons["server-list-refresh"].exists)
    }

    func testAlertSoundPickerOpensAndSelects() {
        launchApp()

        app.buttons["tab-settings"].tap()

        let row = app.buttons["settings-alert-sound"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        row.tap()

        // picker 打开的判定锚点用内部真实元素,避免耦合容器在 XCUITest 中的元素类型。
        let bell = app.buttons["sound-row-bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5), app.debugDescription)
        bell.tap()

        XCTAssertTrue(bell.isSelected, app.debugDescription)
    }

    func testStaleTimeoutPickerOpensAndSelects() {
        launchApp()

        app.buttons["tab-settings"].tap()

        let row = app.buttons["settings-stale-timeout"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        row.tap()

        let option = app.buttons["stale-option-60min"]
        XCTAssertTrue(option.waitForExistence(timeout: 5), app.debugDescription)
        option.tap()

        XCTAssertTrue(option.isSelected, app.debugDescription)
    }

    func testSettingsExternalLinkRowsAreTappable() {
        launchApp()

        app.buttons["tab-settings"].tap()

        // Privacy policy 是 App Store 合规项,必须可点。滚到可见再断言。
        let privacy = app.buttons["settings-privacy-policy"]
        for _ in 0..<4 {
            if privacy.exists && privacy.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(privacy.exists, app.debugDescription)
        XCTAssertTrue(privacy.isHittable, app.debugDescription)

        let barkReference = app.buttons["settings-bark-reference"]
        for _ in 0..<4 {
            if barkReference.exists && barkReference.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(barkReference.exists, app.debugDescription)
        XCTAssertTrue(barkReference.isHittable, app.debugDescription)
    }

    func testHistoryFiltersSeededTimelineItems() {
        launchApp(seedScenario: "search-history")

        app.buttons["tab-history"].tap()

        XCTAssertTrue(app.staticTexts["History Stale Probe"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["History Done Probe"].exists)
        XCTAssertTrue(app.staticTexts["Incoming Alert Probe"].exists)

        app.buttons["history-filter-stale"].tap()
        XCTAssertTrue(app.staticTexts["History Stale Probe"].waitForExistence(timeout: 2))

        app.buttons["history-filter-incoming"].tap()
        XCTAssertTrue(app.staticTexts["Incoming Alert Probe"].waitForExistence(timeout: 2))

        app.buttons["history-filter-archived"].tap()
        XCTAssertTrue(app.staticTexts["History Done Probe"].waitForExistence(timeout: 2))
    }

    func testHistoryAllFilterRestoresSeededTimelineItems() {
        launchApp(seedScenario: "search-history")

        app.buttons["tab-history"].tap()

        XCTAssertTrue(app.staticTexts["History Stale Probe"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["history-filter-stale"].tap()
        XCTAssertTrue(app.staticTexts["History Stale Probe"].waitForExistence(timeout: 2))

        app.buttons["history-filter-all"].tap()

        XCTAssertTrue(app.staticTexts["History Stale Probe"].waitForExistence(timeout: 2), app.debugDescription)
        XCTAssertTrue(app.staticTexts["History Done Probe"].exists)
        XCTAssertTrue(app.staticTexts["Incoming Alert Probe"].exists)
    }

    func testSearchFindsSeededAgentsStepsAndSavedFilters() {
        launchApp(seedScenario: "search-history")

        app.buttons["tab-search"].tap()

        XCTAssertTrue(app.textFields["search-query-field"].waitForExistence(timeout: 5), app.debugDescription)
        app.textFields["search-query-field"].tap()
        app.textFields["search-query-field"].typeText("handoff")

        XCTAssertTrue(app.staticTexts["Release handoff"].waitForExistence(timeout: 3))

        app.buttons["search-scope-steps"].tap()
        XCTAssertTrue(app.staticTexts["Coverage release handoff completed for search results."].waitForExistence(timeout: 2))

        app.buttons["search-clear"].tap()
        app.buttons["search-scope-all"].tap()
        if !app.buttons["search-saved-fails"].waitForExistence(timeout: 1) {
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["search-saved-fails"].waitForExistence(timeout: 2))

        app.buttons["search-saved-fails"].tap()
        XCTAssertTrue(app.staticTexts["Search Failure Probe"].waitForExistence(timeout: 2))
    }

    func testSearchScopesFindAgentsAndInboxResults() {
        launchApp(seedScenario: "search-history")

        app.buttons["tab-search"].tap()

        XCTAssertTrue(app.textFields["search-query-field"].waitForExistence(timeout: 5), app.debugDescription)
        app.textFields["search-query-field"].tap()
        app.textFields["search-query-field"].typeText("probe")

        app.buttons["search-scope-agents"].tap()
        XCTAssertTrue(app.staticTexts["History Stale Probe"].waitForExistence(timeout: 2), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Search Failure Probe"].exists)

        app.buttons["search-clear"].tap()
        app.textFields["search-query-field"].tap()
        app.textFields["search-query-field"].typeText("incoming")

        app.buttons["search-scope-inbox"].tap()
        XCTAssertTrue(app.staticTexts["Incoming Alert Probe"].waitForExistence(timeout: 2), app.debugDescription)
    }

    func testSearchSavedQueriesSelectWaitStuckAndReset() {
        launchApp(seedScenario: "search-status-filters")

        app.buttons["tab-search"].tap()

        XCTAssertTrue(app.textFields["search-query-field"].waitForExistence(timeout: 5), app.debugDescription)
        if !app.buttons["search-saved-wait"].waitForExistence(timeout: 1) {
            app.swipeUp()
        }

        XCTAssertTrue(app.buttons["search-saved-wait"].waitForExistence(timeout: 2), app.debugDescription)
        app.buttons["search-saved-wait"].tap()
        XCTAssertTrue(app.staticTexts["Search Wait Probe"].waitForExistence(timeout: 2), app.debugDescription)

        app.terminate()
        launchApp(seedScenario: "search-status-filters")
        app.buttons["tab-search"].tap()
        XCTAssertTrue(app.textFields["search-query-field"].waitForExistence(timeout: 5), app.debugDescription)
        if !app.buttons["search-saved-stuck"].waitForExistence(timeout: 1) {
            app.swipeUp()
        }

        XCTAssertTrue(app.buttons["search-saved-stuck"].waitForExistence(timeout: 2), app.debugDescription)
        app.buttons["search-saved-stuck"].tap()
        XCTAssertTrue(app.staticTexts["Search Stuck Probe"].waitForExistence(timeout: 2), app.debugDescription)

        app.terminate()
        launchApp(seedScenario: "search-status-filters")
        app.buttons["tab-search"].tap()
        XCTAssertTrue(app.textFields["search-query-field"].waitForExistence(timeout: 5), app.debugDescription)
        if !app.buttons["search-saved-reset"].waitForExistence(timeout: 1) {
            app.swipeUp()
        }

        XCTAssertTrue(app.buttons["search-saved-reset"].waitForExistence(timeout: 2), app.debugDescription)
        app.buttons["search-saved-reset"].tap()
        XCTAssertTrue(app.staticTexts["Search agent cards, step history, and incoming pushes."].waitForExistence(timeout: 2))
    }

    func testSearchStatusChipsFilterAndResetSeededResults() {
        launchApp(seedScenario: "search-status-filters")

        app.buttons["tab-search"].tap()

        XCTAssertTrue(app.textFields["search-query-field"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["search-status-wait"].tap()
        XCTAssertTrue(app.staticTexts["Search Wait Probe"].waitForExistence(timeout: 2), app.debugDescription)

        app.buttons["search-status-wait"].tap()
        XCTAssertTrue(app.staticTexts["Search agent cards, step history, and incoming pushes."].waitForExistence(timeout: 2))

        app.buttons["search-status-stuck"].tap()
        XCTAssertTrue(app.staticTexts["Search Stuck Probe"].waitForExistence(timeout: 2), app.debugDescription)

        app.buttons["search-status-stuck"].tap()
        XCTAssertTrue(app.staticTexts["Search agent cards, step history, and incoming pushes."].waitForExistence(timeout: 2))

        app.buttons["search-status-done"].tap()
        XCTAssertTrue(app.staticTexts["Search Done Probe"].waitForExistence(timeout: 2), app.debugDescription)

        app.buttons["search-status-done"].tap()
        XCTAssertTrue(app.staticTexts["Search agent cards, step history, and incoming pushes."].waitForExistence(timeout: 2))

        app.buttons["search-status-fail"].tap()
        XCTAssertTrue(app.staticTexts["Search Failure Probe"].waitForExistence(timeout: 2), app.debugDescription)
    }

    func testSearchAgentAndDateMenusFilterSeededResults() {
        launchApp(seedScenario: "search-menu-filters")

        app.buttons["tab-search"].tap()

        XCTAssertTrue(app.textFields["search-query-field"].waitForExistence(timeout: 5), app.debugDescription)
        app.textFields["search-query-field"].tap()
        app.textFields["search-query-field"].typeText("Menu")

        XCTAssertTrue(app.staticTexts["Menu Recent Probe"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Menu Old Probe"].exists)

        app.buttons["search-agent-filter"].tap()
        tapMenuOption(identifier: "search-agent-option-menu-old", label: "menu-old")
        XCTAssertTrue(app.staticTexts["Menu Old Probe"].waitForExistence(timeout: 2), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Menu Recent Probe"].waitForExistence(timeout: 1), app.debugDescription)

        app.buttons["search-agent-filter"].tap()
        tapMenuOption(identifier: "search-agent-option-all", label: "all")
        XCTAssertTrue(app.staticTexts["Menu Recent Probe"].waitForExistence(timeout: 2), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Menu Old Probe"].exists)

        app.buttons["search-date-filter"].tap()
        tapMenuOption(identifier: "search-date-option-last7d", label: "last 7d")
        XCTAssertTrue(app.staticTexts["Menu Recent Probe"].waitForExistence(timeout: 2), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Menu Old Probe"].waitForExistence(timeout: 1), app.debugDescription)
    }

    func testSeededAgentDetailSupportsPrimaryActions() {
        launchApp(seedScenario: "agent-detail")

        XCTAssertTrue(app.staticTexts["Codex Coverage Probe"].waitForExistence(timeout: 5), app.debugDescription)
        app.staticTexts["Codex Coverage Probe"].tap()

        XCTAssertTrue(app.staticTexts["Dossier"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Need review"].exists)

        app.buttons["agent-detail-pin"].tap()
        XCTAssertEqual(app.buttons["agent-detail-pin"].label, "UNPIN")

        app.buttons["agent-detail-mute"].tap()
        XCTAssertEqual(app.buttons["agent-detail-mute"].label, "UNMUTE")

        app.buttons["agent-detail-summarize"].tap()
        XCTAssertTrue(app.staticTexts["Coverage seed summary is ready."].waitForExistence(timeout: 2))

        app.buttons["agent-detail-done"].tap()
        app.buttons["agent-detail-archive"].tap()
    }

    func testDashboardContextMenuCanPinTask() {
        launchApp(seedScenario: "agent-detail")

        let seededTask = app.staticTexts["Codex Coverage Probe"]
        XCTAssertTrue(seededTask.waitForExistence(timeout: 5), app.debugDescription)

        seededTask.press(forDuration: 1)
        tapMenuOption(identifier: "Pin", label: "Pin")

        seededTask.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Unpin"].waitForExistence(timeout: 2), app.debugDescription)
    }

    func testDashboardContextMenuCanMuteTask() {
        launchApp(seedScenario: "agent-detail")

        let seededTask = app.staticTexts["Codex Coverage Probe"]
        XCTAssertTrue(seededTask.waitForExistence(timeout: 5), app.debugDescription)

        seededTask.press(forDuration: 1)
        tapMenuOption(identifier: "Mute", label: "Mute")

        seededTask.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Unmute"].waitForExistence(timeout: 2), app.debugDescription)
    }

    func testDashboardContextMenuCanMarkTaskDone() {
        launchApp(seedScenario: "agent-detail")

        let seededTask = app.staticTexts["Codex Coverage Probe"]
        XCTAssertTrue(seededTask.waitForExistence(timeout: 5), app.debugDescription)

        seededTask.press(forDuration: 1)
        tapMenuOption(identifier: "Mark Done", label: "Mark Done")

        XCTAssertTrue(app.staticTexts["SETTLED"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.staticTexts["DONE"].exists, app.debugDescription)
        XCTAssertTrue(seededTask.exists, app.debugDescription)
    }

    func testDashboardContextMenuCanArchiveTask() {
        launchApp(seedScenario: "agent-detail")

        let seededTask = app.staticTexts["Codex Coverage Probe"]
        XCTAssertTrue(seededTask.waitForExistence(timeout: 5), app.debugDescription)

        seededTask.press(forDuration: 1)
        tapMenuOption(identifier: "Archive", label: "Archive")

        XCTAssertTrue(
            app.staticTexts["Send one push. Get one living card."].waitForExistence(timeout: 3),
            app.debugDescription
        )

        app.buttons["tab-history"].tap()
        XCTAssertTrue(app.staticTexts["Codex Coverage Probe"].waitForExistence(timeout: 3), app.debugDescription)
    }

    func testAgentDetailDoneMovesTaskIntoSettled() {
        launchApp(seedScenario: "agent-detail")

        XCTAssertTrue(app.staticTexts["Codex Coverage Probe"].waitForExistence(timeout: 5), app.debugDescription)
        app.staticTexts["Codex Coverage Probe"].tap()
        XCTAssertTrue(app.buttons["agent-detail-done"].waitForExistence(timeout: 3), app.debugDescription)

        app.buttons["agent-detail-done"].tap()
        app.buttons["←"].tap()

        XCTAssertTrue(app.staticTexts["SETTLED"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.staticTexts["DONE"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["Codex Coverage Probe"].exists, app.debugDescription)
    }

    func testAgentDetailArchiveMovesTaskFromDashboardIntoHistory() {
        launchApp(seedScenario: "agent-detail")

        XCTAssertTrue(app.staticTexts["Codex Coverage Probe"].waitForExistence(timeout: 5), app.debugDescription)
        app.staticTexts["Codex Coverage Probe"].tap()
        XCTAssertTrue(app.buttons["agent-detail-archive"].waitForExistence(timeout: 3), app.debugDescription)

        app.buttons["agent-detail-archive"].tap()
        app.buttons["←"].tap()

        XCTAssertTrue(
            app.staticTexts["Send one push. Get one living card."].waitForExistence(timeout: 3),
            app.debugDescription
        )

        app.buttons["tab-history"].tap()
        XCTAssertTrue(app.staticTexts["Codex Coverage Probe"].waitForExistence(timeout: 3), app.debugDescription)
    }

    func testSeededAgentDetailCanReturnToDashboard() {
        launchApp(seedScenario: "agent-detail")

        XCTAssertTrue(app.staticTexts["Codex Coverage Probe"].waitForExistence(timeout: 5), app.debugDescription)
        app.staticTexts["Codex Coverage Probe"].tap()

        XCTAssertTrue(app.staticTexts["Dossier"].waitForExistence(timeout: 3), app.debugDescription)
        app.buttons["←"].tap()

        XCTAssertTrue(app.staticTexts["Codex Coverage Probe"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Dossier"].exists)
    }

    private func launchApp(
        seedScenario: String? = nil,
        barkClientMode: String? = nil,
        notificationStatusKind: String? = nil,
        notificationStatusDetail: String? = nil,
        deviceToken: String? = nil
    ) {
        let suiteName = "BarkMateUITests-\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: suiteName)

        app = XCUIApplication()
        app.launchEnvironment["BARKAGENT_UI_TESTING"] = "1"
        app.launchEnvironment["BARKAGENT_TEST_DEFAULTS_SUITE"] = suiteName
        app.launchEnvironment["SIM_SKIP_NOTIF_PROMPT"] = "1"
        if let seedScenario {
            app.launchEnvironment["BARKAGENT_UI_SEED_SCENARIO"] = seedScenario
        }
        if let barkClientMode {
            app.launchEnvironment["BARKAGENT_UI_BARK_CLIENT"] = barkClientMode
        }
        if let notificationStatusKind {
            app.launchEnvironment["BARKAGENT_UI_NOTIFICATION_STATUS"] = notificationStatusKind
        }
        if let notificationStatusDetail {
            app.launchEnvironment["BARKAGENT_UI_NOTIFICATION_DETAIL"] = notificationStatusDetail
        }
        if let deviceToken {
            app.launchEnvironment["BARKAGENT_UI_DEVICE_TOKEN"] = deviceToken
        }
        app.launch()
    }

    private func tapMenuOption(identifier: String, label: String) {
        let identifiedButton = app.buttons[identifier]
        if identifiedButton.waitForExistence(timeout: 2) {
            identifiedButton.tap()
            return
        }

        let labeledButton = app.buttons[label]
        if labeledButton.waitForExistence(timeout: 2) {
            labeledButton.tap()
            return
        }

        let labeledText = app.staticTexts[label]
        XCTAssertTrue(labeledText.waitForExistence(timeout: 2), app.debugDescription)
        labeledText.tap()
    }
}
