import XCTest

final class Tier1FlowUITest: XCTestCase {
    func test_laser_toggle_and_side_by_side_compare() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let sidebar = app.collectionViews["exhibit.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
        app.staticTexts["D-001"].tap()

        let publish = app.buttons["toolbar.publish"]
        XCTAssertTrue(publish.waitForExistence(timeout: 5))
        publish.tap()

        // Laser toggle is reachable and toggles without crashing.
        let laser = app.buttons["laser.toggle"]
        XCTAssertTrue(laser.waitForExistence(timeout: 5))
        laser.tap()
        laser.tap()

        // Side-by-side: Compare is enabled once an exhibit is published.
        let compareOpen = app.buttons["compare.open"]
        XCTAssertTrue(compareOpen.waitForExistence(timeout: 5))
        XCTAssertTrue(compareOpen.isEnabled)
        compareOpen.tap()

        // Pick a second exhibit, confirm the split appears, then stop.
        let pick = app.buttons["compare.pick.S-014"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()

        let stop = app.buttons["compare.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(app.buttons["compare.open"].waitForExistence(timeout: 5))
    }
}
