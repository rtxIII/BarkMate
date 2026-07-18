import XCTest
import UIKit

@MainActor
final class BarkMateScreenshotRegressionTests: XCTestCase {

    private var app: XCUIApplication!
    private let allowedPixelDifference = 0.01

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testDashboardAndAgentDetailScreenshotsMatchBaseline() {
        launchApp(seedScenario: "agent-detail")

        XCTAssertTrue(app.staticTexts["Codex Coverage Probe"].waitForExistence(timeout: 5), app.debugDescription)
        assertMatchesScreenshot(named: "dashboard-agent-detail-seed")

        app.staticTexts["Codex Coverage Probe"].tap()
        XCTAssertTrue(app.staticTexts["Dossier"].waitForExistence(timeout: 3), app.debugDescription)
        assertMatchesScreenshot(named: "agent-detail")
    }

    func testHistoryAndSearchScreenshotsMatchBaseline() {
        launchApp(seedScenario: "search-history")

        app.buttons["tab-history"].tap()
        XCTAssertTrue(app.staticTexts["History Stale Probe"].waitForExistence(timeout: 5), app.debugDescription)
        assertMatchesScreenshot(named: "history-seeded")

        app.buttons["tab-search"].tap()
        XCTAssertTrue(app.textFields["search-query-field"].waitForExistence(timeout: 5), app.debugDescription)
        app.textFields["search-query-field"].tap()
        app.textFields["search-query-field"].typeText("handoff")
        XCTAssertTrue(app.staticTexts["Release handoff"].waitForExistence(timeout: 3), app.debugDescription)
        assertMatchesScreenshot(named: "search-handoff")
    }

    func testSettingsSetupAndServerListScreenshotsMatchBaseline() {
        launchApp(seedScenario: "server-health")

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-manage-servers"].waitForExistence(timeout: 5), app.debugDescription)
        assertMatchesScreenshot(named: "settings-default")

        app.buttons["settings-rerun-installer"].tap()
        XCTAssertTrue(app.buttons["setup-copy-install"].waitForExistence(timeout: 3), app.debugDescription)
        assertMatchesScreenshot(named: "setup-guide")

        app.buttons["←"].tap()
        XCTAssertTrue(app.buttons["settings-manage-servers"].waitForExistence(timeout: 3), app.debugDescription)
        app.buttons["settings-manage-servers"].tap()
        XCTAssertTrue(app.staticTexts["Refresh Probe"].waitForExistence(timeout: 3), app.debugDescription)
        assertMatchesScreenshot(named: "server-list")
    }

    private func launchApp(seedScenario: String? = nil) {
        let suiteName = "BarkMateScreenshotTests-\(UUID().uuidString)"
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
        if let seedScenario {
            app.launchEnvironment["BARKAGENT_UI_SEED_SCENARIO"] = seedScenario
        }
        app.launch()
    }

    private func assertMatchesScreenshot(
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let screenshot = app.screenshot().pngRepresentation
        let baselineURL = baselineDirectory.appendingPathComponent("\(name).png")

        if shouldRecordScreenshots {
            do {
                try FileManager.default.createDirectory(
                    at: baselineDirectory,
                    withIntermediateDirectories: true
                )
                try screenshot.write(to: baselineURL, options: .atomic)
                addAttachment(data: screenshot, name: "recorded-\(name)")
            } catch {
                XCTFail("Failed to record screenshot baseline \(name): \(error)", file: file, line: line)
            }
            return
        }

        guard FileManager.default.fileExists(atPath: baselineURL.path) else {
            XCTFail(
                "Missing screenshot baseline \(baselineURL.path). Re-run with BARKAGENT_RECORD_SCREENSHOTS=1.",
                file: file,
                line: line
            )
            addAttachment(data: screenshot, name: "actual-\(name)")
            return
        }

        do {
            let baseline = try Data(contentsOf: baselineURL)
            let result = try ScreenshotComparator.compare(
                baselinePNG: baseline,
                actualPNG: screenshot,
                allowedPixelDifference: allowedPixelDifference
            )
            if !result.matches {
                addAttachment(data: baseline, name: "baseline-\(name)")
                addAttachment(data: screenshot, name: "actual-\(name)")
                if let diffPNG = result.diffPNG {
                    addAttachment(data: diffPNG, name: "diff-\(name)")
                }
                XCTFail(
                    "\(name) screenshot changed: \(String(format: "%.3f", result.differenceRatio * 100))% pixels differ; allowed \(String(format: "%.3f", allowedPixelDifference * 100))%.",
                    file: file,
                    line: line
                )
            }
        } catch {
            XCTFail("Failed to compare screenshot \(name): \(error)", file: file, line: line)
            addAttachment(data: screenshot, name: "actual-\(name)")
        }
    }

    private var shouldRecordScreenshots: Bool {
        ProcessInfo.processInfo.environment["BARKAGENT_RECORD_SCREENSHOTS"] == "1" ||
            FileManager.default.fileExists(atPath: baselineDirectory.appendingPathComponent(".record").path)
    }

    private var baselineDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("__Screenshots__/iPhone17", isDirectory: true)
    }

    private func addAttachment(data: Data, name: String) {
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct ScreenshotComparisonResult {
    let matches: Bool
    let differenceRatio: Double
    let diffPNG: Data?
}

private enum ScreenshotComparator {

    static func compare(
        baselinePNG: Data,
        actualPNG: Data,
        allowedPixelDifference: Double
    ) throws -> ScreenshotComparisonResult {
        guard let baselineImage = UIImage(data: baselinePNG),
              let actualImage = UIImage(data: actualPNG) else {
            throw ComparisonError.invalidPNG
        }

        let baseline = try PixelBuffer(image: baselineImage)
        let actual = try PixelBuffer(image: actualImage)
        guard baseline.width == actual.width, baseline.height == actual.height else {
            return ScreenshotComparisonResult(matches: false, differenceRatio: 1, diffPNG: nil)
        }

        var changedPixels = 0
        var diff = [UInt8](repeating: 255, count: baseline.pixels.count)
        let pixelCount = baseline.width * baseline.height

        for index in 0..<pixelCount {
            let offset = index * 4
            let delta = abs(Int(baseline.pixels[offset]) - Int(actual.pixels[offset]))
                + abs(Int(baseline.pixels[offset + 1]) - Int(actual.pixels[offset + 1]))
                + abs(Int(baseline.pixels[offset + 2]) - Int(actual.pixels[offset + 2]))

            if delta > 24 {
                changedPixels += 1
                diff[offset] = 255
                diff[offset + 1] = 0
                diff[offset + 2] = 80
                diff[offset + 3] = 255
            } else {
                diff[offset] = actual.pixels[offset]
                diff[offset + 1] = actual.pixels[offset + 1]
                diff[offset + 2] = actual.pixels[offset + 2]
                diff[offset + 3] = 255
            }
        }

        let ratio = Double(changedPixels) / Double(pixelCount)
        return ScreenshotComparisonResult(
            matches: ratio <= allowedPixelDifference,
            differenceRatio: ratio,
            diffPNG: ratio <= allowedPixelDifference ? nil : PixelBuffer.pngData(
                pixels: diff,
                width: baseline.width,
                height: baseline.height
            )
        )
    }

    private enum ComparisonError: Error {
        case invalidPNG
    }
}

private struct PixelBuffer {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init(image: UIImage) throws {
        guard let cgImage = image.cgImage else {
            throw BufferError.missingCGImage
        }

        width = cgImage.width
        height = cgImage.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw BufferError.contextCreationFailed
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        pixels = buffer
    }

    static func pngData(pixels: [UInt8], width: Int, height: Int) -> Data? {
        var mutablePixels = pixels
        guard let context = CGContext(
            data: &mutablePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
            let image = context.makeImage() else {
            return nil
        }
        return UIImage(cgImage: image).pngData()
    }

    private enum BufferError: Error {
        case missingCGImage
        case contextCreationFailed
    }
}
