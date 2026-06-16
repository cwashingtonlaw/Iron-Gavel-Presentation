import XCTest

final class TrialRecordUITest: XCTestCase {
    func test_export_button_and_disposition_sheet() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let exportButton = app.buttons["toolbar.exportList"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 10))
        XCTAssertTrue(exportButton.isEnabled)

        let sidebar = app.collectionViews["exhibit.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
        app.staticTexts["D-001"].tap()

        let open = app.buttons["disposition.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()

        let ruling = app.textFields["disposition.ruling"]
        XCTAssertTrue(ruling.waitForExistence(timeout: 5))
        ruling.tap()
        ruling.typeText("Overruled")

        app.buttons["disposition.save"].tap()
        // Sheet dismisses; the preview pane is interactive again.
        XCTAssertTrue(app.buttons["disposition.open"].waitForExistence(timeout: 5))
    }
}
