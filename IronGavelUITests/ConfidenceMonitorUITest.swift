import XCTest

final class ConfidenceMonitorUITest: XCTestCase {
    func test_confidence_monitor_and_panic_blank() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        // The confidence monitor is always visible in the presenter.
        XCTAssertTrue(app.otherElements["confidence.monitor"].waitForExistence(timeout: 10))

        let sidebar = app.collectionViews["exhibit.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))

        // Publish an admitted exhibit, then use the panic blackout in the monitor.
        app.staticTexts["D-001"].tap()
        let publish = app.buttons["toolbar.publish"]
        XCTAssertTrue(publish.waitForExistence(timeout: 5))
        publish.tap()

        let panic = app.buttons["confidence.blank"]
        XCTAssertTrue(panic.waitForExistence(timeout: 5))
        XCTAssertEqual(panic.label, "Blank Jury")
        panic.tap()
        XCTAssertEqual(panic.label, "Go Live")
        panic.tap()
        XCTAssertEqual(panic.label, "Blank Jury")
    }
}
