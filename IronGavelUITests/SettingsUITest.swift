import XCTest

final class SettingsUITest: XCTestCase {
    func test_settings_sheet_opens_and_toggles() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let gear = app.buttons["toolbar.settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()

        let banner = app.switches["settings.juryBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        banner.tap()

        let done = app.buttons["settings.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        XCTAssertTrue(app.buttons["toolbar.settings"].waitForExistence(timeout: 5))
    }
}
