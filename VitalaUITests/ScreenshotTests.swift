import XCTest

/// Captures App Store screenshots from seeded sample data. Skipped in normal
/// runs; enable with:
///   TEST_RUNNER_VITALA_SCREENSHOTS=1 TEST_RUNNER_VITALA_SCREENSHOT_DIR=/path/to/folder \
///   xcodebuild test -only-testing:VitalaUITests/ScreenshotTests ...
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["VITALA_SCREENSHOTS"] == "1",
                          "Set TEST_RUNNER_VITALA_SCREENSHOTS=1 to capture screenshots")
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-seedSampleData"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        settle()
        snap(app, "01-Today")

        app.tabBars.buttons["Activity"].tap(); settle()
        snap(app, "02-Activity")

        app.tabBars.buttons["Nutrition"].tap(); settle()
        snap(app, "03-Nutrition")

        app.tabBars.buttons["Sleep"].tap(); settle()
        snap(app, "04-Sleep")

        app.tabBars.buttons["Mindful"].tap(); settle()
        app.buttons["Start a one-minute reset"].tap()
        sleep(3)
        snap(app, "05-Breathing")
        app.buttons["End session"].tap()
        app.buttons["Discard"].tap()

        app.tabBars.buttons["Today"].tap()
        app.buttons["profile.button"].firstMatch.tap()
        app.buttons["profile.progress"].tap(); settle()
        snap(app, "06-Progress")
    }

    private func settle() { sleep(2) }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // Optionally also write straight to a folder on the Mac.
        if let dir = ProcessInfo.processInfo.environment["VITALA_SCREENSHOT_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
