import XCTest

/// App Store 商店截图生成器（非回归测试）。
///
/// 在 iPhone 17 Pro Max（6.9" / 1320×2868）上跑，用 `showcase` seed 导航到 6 个
/// 关键页面，把整屏截图写到仓库的 `doc/app-store-screenshots/`。产出的是设备分辨率
/// 裸图，可直接上传 App Store Connect。
///
/// 运行：
///   xcodebuild -project BarkMate/BarkMate.xcodeproj -scheme BarkMate \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' \
///     -only-testing:BarkMateUITests/BarkMateAppStoreScreenshotTests test
@MainActor
final class BarkMateAppStoreScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testCaptureAppStoreScreenshots() {
        launchShowcase()

        // 1. Agents dashboard —— heads-up 面板 + needs-you / running / settled 三段。
        XCTAssertTrue(app.staticTexts["backend-refactor"].waitForExistence(timeout: 8), app.debugDescription)
        capture("01-agents-dashboard")

        // 2. Agent detail —— 点 hero 卡进详情，展示 step 历史。
        app.staticTexts["backend-refactor"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Refactoring auth middleware"].waitForExistence(timeout: 5), app.debugDescription)
        capture("02-agent-detail")
        if app.buttons["←"].exists { app.buttons["←"].tap() }

        // 3. History。
        app.buttons["tab-history"].tap()
        XCTAssertTrue(app.buttons["tab-history"].waitForExistence(timeout: 5), app.debugDescription)
        capture("03-history")

        // 4. Settings。
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-manage-servers"].waitForExistence(timeout: 5), app.debugDescription)
        capture("04-settings")

        // 5. Setup —— 从 settings 打开安装向导。
        app.buttons["settings-rerun-installer"].tap()
        XCTAssertTrue(app.buttons["setup-copy-install"].waitForExistence(timeout: 3), app.debugDescription)
        capture("05-setup")
    }

    private func launchShowcase() {
        let suiteName = "BarkMateAppStore-\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: suiteName)

        app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryM"
        ]
        app.launchEnvironment["BARKAGENT_UI_TESTING"] = "1"
        app.launchEnvironment["BARKAGENT_TEST_DEFAULTS_SUITE"] = suiteName
        app.launchEnvironment["SIM_SKIP_NOTIF_PROMPT"] = "1"
        app.launchEnvironment["BARKAGENT_UI_SEED_SCENARIO"] = "showcase"
        app.launch()
    }

    private func capture(_ name: String) {
        let png = app.screenshot().pngRepresentation

        // 附到 xcresult（无论写盘成败都留证据）。
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            try png.write(to: outputDirectory.appendingPathComponent("\(name).png"), options: .atomic)
        } catch {
            XCTFail("Failed to write screenshot \(name): \(error)")
        }
    }

    /// 从本文件位置上溯到仓库根，再进 doc/app-store-screenshots/6.9-inch。
    /// #filePath = <repo>/BarkMate/App/UITests/BarkMateUITests/<thisfile>.swift
    private var outputDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // BarkMateUITests
            .deletingLastPathComponent()  // UITests
            .deletingLastPathComponent()  // App
            .deletingLastPathComponent()  // BarkMate
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("doc/app-store-screenshots/6.9-inch", isDirectory: true)
    }
}
