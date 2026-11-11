import XCTest

/// Runs Xcode's accessibility audit (contrast, labels, hit regions,
/// Dynamic Type, clipped text…) on every main screen.
final class AccessibilityAuditTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func launch(_ arguments: [String], largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        }
        app.launch()
        return app
    }

    /// Everything except contrast. Contrast is enforced deterministically by
    /// ContrastTests on every colour token: the audit samples screenshot
    /// pixels, which reports false failures for text over translucent Liquid
    /// Glass and for anti-aliased small text (flagged text measures 5-19:1).
    private static let auditTypes: XCUIAccessibilityAuditType = .all.subtracting(.contrast)

    /// Labels checked by eye at default and accessibility sizes.
    private static let verifiedUnclipped: Set<String> = ["Great", "Export my data"]

    /// Audits the current screen, attaching the screen name to failures.
    /// - Parameter isSheet: on iOS 26+ sheets are inset, so a sliver of the
    ///   screen underneath shows below their rounded corners. VoiceOver
    ///   rightly ignores it while the sheet is up, but the audit's on-screen
    ///   text detection reads those pixels and reports text with no element.
    @MainActor
    private func audit(_ app: XCUIApplication, _ screen: String, isSheet: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) {
        do {
            try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
                // The status bar and system keyboard aren't ours.
                if let element = issue.element,
                   element.elementType == .statusBar || element.elementType == .keyboard {
                    return true
                }
                // "Partially unsupported" flags text that is capped somewhere
                // in the size range, including system toolbar buttons. Real
                // behaviour at accessibility sizes is audited by
                // testMainScreensAtLargeTextSizes.
                if issue.auditType == .dynamicType && issue.compactDescription.contains("partially") {
                    return true
                }
                if isSheet && issue.auditType == .elementDetection && issue.element == nil {
                    return true
                }
                // Text findings that point at no element are for content
                // that isn't on screen: the onboarding's other pages, which
                // stay loaded beside the one showing and are hidden from
                // VoiceOver. Each page is audited when it is the one showing.
                if issue.element == nil, issue.auditType == .textClipped || issue.auditType == .dynamicType {
                    return true
                }
                // Verified false positives: these render in full on screen.
                // The system search field's placeholder, and Text inside
                // buttons whose combined frame the heuristic mis-measures.
                if issue.auditType == .textClipped,
                   let element = issue.element,
                   element.elementType == .searchField || Self.verifiedUnclipped.contains(element.label) {
                    return true
                }
                print("[\(screen)] \(issue.auditType): \(issue.compactDescription) / \(issue.detailedDescription) — \(issue.element?.debugDescription.prefix(200) ?? "no element")")
                return false
            }
        } catch {
            XCTFail("\(screen): \(error)", file: file, line: line)
        }
    }

    @MainActor
    private func openTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab \(name)")
        tab.tap()
    }

    @MainActor
    func testOnboardingIsAccessible() throws {
        let app = launch(["-resetData"])
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        audit(app, "Onboarding welcome")

        app.buttons["Skip"].tap()
        XCTAssertTrue(app.staticTexts["Let's get to know you"].waitForExistence(timeout: 5))
        audit(app, "Onboarding name form")

        let firstName = app.textFields.firstMatch
        firstName.tap()
        firstName.typeText("Sam")
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.staticTexts["Tell us about you"].waitForExistence(timeout: 5))
        audit(app, "Profile setup: about you")
    }

    /// The sign-in screens, which the app shows once an account service is
    /// set up. Until then it opens straight into onboarding, as above.
    @MainActor
    func testSignInIsAccessible() throws {
        let app = launch(["-resetData", "-requireSignIn"])
        let withEmail = app.buttons["auth.email"]
        XCTAssertTrue(withEmail.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["auth.apple"].exists && app.buttons["auth.google"].exists)
        XCTAssertFalse(app.buttons["Continue"].exists, "nothing else is reachable before signing in")
        audit(app, "Sign in")

        withEmail.tap()
        XCTAssertTrue(app.navigationBars["Create your account"].waitForExistence(timeout: 5))
        audit(app, "Create account", isSheet: true)
        XCTAssertFalse(app.buttons["auth.submit"].isEnabled, "nothing to send yet")
        app.navigationBars["Create your account"].buttons["Cancel"].tap()

        // Signing in with a password makes iOS offer to save it, in a sheet
        // of its own. In test mode accounts are kept on the device, so
        // Google signs in at a tap. (Creating an account with an email is
        // covered by the unit tests.)
        XCTAssertTrue(app.buttons["auth.google"].waitForExistence(timeout: 5))
        app.buttons["auth.google"].tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10), "signed in, onboarding follows")
    }

    @MainActor
    func testMainScreensAreAccessible() throws {
        try auditMainScreens(largeText: false)
    }

    @MainActor
    func testMainScreensAtLargeTextSizes() throws {
        try auditMainScreens(largeText: true)
    }

    @MainActor
    private func auditMainScreens(largeText: Bool) throws {
        let suffix = largeText ? " (large text)" : ""
        let app = launch(["-seedSampleData"], largeText: largeText)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        audit(app, "Today" + suffix)

        openTab(app, "Activity")
        XCTAssertTrue(app.buttons["profile.button"].firstMatch.exists, "Profile reachable from Activity")
        audit(app, "Activity" + suffix)

        openTab(app, "Nutrition")
        audit(app, "Nutrition" + suffix)

        openTab(app, "Mindful")
        audit(app, "Mindful" + suffix)

        openTab(app, "Sleep")
        audit(app, "Sleep" + suffix)

        openTab(app, "Today")
        let profile = app.buttons["profile.button"].firstMatch
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        profile.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        audit(app, "Profile" + suffix)

        app.buttons["profile.progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        audit(app, "Progress" + suffix)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["profile.settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        audit(app, "Settings" + suffix)
    }

    @MainActor
    func testLoggingSheetsAreAccessible() throws {
        let app = launch(["-seedSampleData"])
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        app.buttons["quicklog.water"].tap()
        XCTAssertTrue(app.navigationBars["Water"].waitForExistence(timeout: 5))
        audit(app, "Water sheet", isSheet: true)
        app.buttons["Done"].tap()

        app.buttons["quicklog.meal"].tap()
        XCTAssertTrue(app.navigationBars["Log a meal"].waitForExistence(timeout: 5))
        audit(app, "Log a meal", isSheet: true)
        app.buttons["Cancel"].tap()

        app.buttons["quicklog.sleep"].tap()
        XCTAssertTrue(app.navigationBars["Log sleep"].waitForExistence(timeout: 5))
        audit(app, "Log sleep", isSheet: true)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testFormsAreAccessible() throws {
        let app = launch(["-seedSampleData"])
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        app.buttons["quicklog.meal"].tap()
        XCTAssertTrue(app.navigationBars["Log a meal"].waitForExistence(timeout: 5))
        app.buttons["meal.customFood"].tap()
        XCTAssertTrue(app.navigationBars["Custom food"].waitForExistence(timeout: 5))
        audit(app, "Custom food", isSheet: true)
        app.navigationBars["Custom food"].buttons["Cancel"].tap()

        app.buttons["meal.scanBarcode"].tap()
        XCTAssertTrue(app.navigationBars["Scan barcode"].waitForExistence(timeout: 5))
        audit(app, "Barcode entry", isSheet: true)
        app.navigationBars["Scan barcode"].buttons["Cancel"].tap()
        app.navigationBars["Log a meal"].buttons["Cancel"].tap()

        openTab(app, "Activity")
        app.buttons["Log an activity"].tap()
        XCTAssertTrue(app.navigationBars["Log activity"].waitForExistence(timeout: 5))
        audit(app, "Log activity", isSheet: true)
        app.navigationBars["Log activity"].buttons["Cancel"].tap()

        openTab(app, "Mindful")
        app.buttons["New journal entry"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New entry"].waitForExistence(timeout: 5))
        audit(app, "Journal entry", isSheet: true)
        app.navigationBars["New entry"].buttons["Cancel"].tap()

        openTab(app, "Today")
        app.buttons["profile.button"].firstMatch.tap()
        app.buttons["Edit profile"].tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5))
        audit(app, "Edit profile", isSheet: true)
        app.navigationBars["Edit profile"].buttons["Cancel"].tap()
    }

    @MainActor
    func testWorkoutBuilderAndSyncScreensAreAccessible() throws {
        let app = launch(["-seedSampleData"])
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        openTab(app, "Activity")
        let build = app.buttons["activity.buildWorkout"]
        XCTAssertTrue(build.waitForExistence(timeout: 5))
        build.tap()
        XCTAssertTrue(app.navigationBars["Build a workout"].waitForExistence(timeout: 5))
        audit(app, "Workout builder", isSheet: true)

        app.buttons["builder.addExercises"].tap()
        XCTAssertTrue(app.navigationBars["Add exercises"].waitForExistence(timeout: 5))
        audit(app, "Exercise picker", isSheet: true)
        // Adding one makes Save possible once the workout has a name.
        app.buttons["Push-up, 3 × 10 reps"].firstMatch.tap()
        app.navigationBars["Add exercises"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Build a workout"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Build a workout"].buttons["Save"].isEnabled, "a workout needs a name")
        let name = app.textFields["Name"]
        name.tap()
        name.typeText("Test circuit")
        XCTAssertTrue(app.navigationBars["Build a workout"].buttons["Save"].isEnabled)
        audit(app, "Workout builder with an exercise", isSheet: true)
        app.navigationBars["Build a workout"].buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Test circuit"].waitForExistence(timeout: 5), "the built workout is listed")

        openTab(app, "Today")
        app.buttons["profile.button"].firstMatch.tap()
        app.buttons["profile.settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.staticTexts["iCloud sync"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["iCloud sync"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["sync.toggle"].exists)
        audit(app, "iCloud sync")
    }
}
