import XCTest

/// End-to-end food search against the live USDA FoodData Central API.
/// Needs the network, so it's skipped unless enabled:
///   TEST_RUNNER_VITALA_NETWORK_TESTS=1 xcodebuild test -only-testing:VitalaUITests/FoodSearchTests ...
final class FoodSearchTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["VITALA_NETWORK_TESTS"] == "1",
                          "Set TEST_RUNNER_VITALA_NETWORK_TESTS=1 to run live API tests")
        continueAfterFailure = false
    }

    @MainActor
    func testSearchingUSDAAndAddingAPortion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-seedSampleData"]
        app.launch()

        app.buttons["quicklog.meal"].tap()
        let search = app.searchFields["Search foods"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("greek yogurt")

        // Online rows read "<name>, <brand · >NNN kcal per <portion>".
        let online = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'kcal per'")).firstMatch
        XCTAssertTrue(online.waitForExistence(timeout: 20), "USDA results should appear")
        attach(app, "USDA results")
        online.tap()

        XCTAssertTrue(app.navigationBars["Add food"].waitForExistence(timeout: 5))
        attach(app, "Portion sheet")
        app.navigationBars["Add food"].buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["In this meal"].waitForExistence(timeout: 5))
        attach(app, "Added to meal")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
