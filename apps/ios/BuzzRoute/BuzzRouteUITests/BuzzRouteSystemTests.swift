import XCTest

/// System smoke test for Buzz Route on Simulator.
final class BuzzRouteSystemTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testTwinMapGrokFlow() throws {
        // App should show Buzz Route chrome quickly
        let title = app.staticTexts["Buzz Route"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Buzz Route title missing — launch failed")

        // Twin chrome or map chrome
        let askTwin = app.buttons["askGrokTwin"]
        let planOnMap = app.buttons["planOnMap"]
        let openGrokHeader = app.buttons["openGrokHeader"]
        let toggle = app.buttons["toggleTwinMap"]

        if askTwin.waitForExistence(timeout: 5) {
            XCTAssertTrue(planOnMap.exists, "Plan on Map missing in twin mode")
            askTwin.tap()
        } else {
            XCTAssertTrue(openGrokHeader.waitForExistence(timeout: 5), "Grok header button missing")
            openGrokHeader.tap()
        }

        // Grok sheet
        let grokTitle = app.navigationBars["Grok Bot"]
        XCTAssertTrue(grokTitle.waitForExistence(timeout: 8), "Grok Bot sheet did not open")

        let suggestion = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "when should I leave")).firstMatch
        if suggestion.waitForExistence(timeout: 3) {
            suggestion.tap()
        } else {
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 2) {
                field.tap()
                field.typeText("Hey Grok, using my calendar, when should I leave?")
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "arrow")).firstMatch.tap()
            }
        }

        // Expect an assistant reply mentioning TripTrace or calendar/leave
        let reply = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                        "TripTrace", "calendar", "Leave")
        ).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 8), "Grok Bot did not produce a reply")

        // Dismiss sheet
        app.swipeDown()
        sleep(1)

        // Toggle twin/map if available
        if toggle.exists {
            toggle.tap()
            sleep(1)
            toggle.tap()
        }
    }
}
