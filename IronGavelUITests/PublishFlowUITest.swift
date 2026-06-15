import XCTest

final class PublishFlowUITest: XCTestCase {
    func test_publish_admitted_then_blank() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let sidebar = app.collectionViews["exhibit.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        let admittedRow = app.staticTexts["D-001"]
        XCTAssertTrue(admittedRow.waitForExistence(timeout: 5))
        admittedRow.tap()

        let publish = app.buttons["toolbar.publish"]
        XCTAssertTrue(publish.waitForExistence(timeout: 5))
        XCTAssertTrue(publish.isEnabled)
        publish.tap()

        let blank = app.buttons["toolbar.blank"]
        XCTAssertEqual(blank.label, "Blank")
        blank.tap()
        XCTAssertEqual(blank.label, "Live")

        let pending = app.staticTexts["S-014"]
        XCTAssertTrue(pending.exists)
        pending.tap()
        XCTAssertFalse(publish.isEnabled)
    }
}
