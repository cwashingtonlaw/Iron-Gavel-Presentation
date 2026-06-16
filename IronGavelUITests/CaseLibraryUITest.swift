import XCTest

final class CaseLibraryUITest: XCTestCase {
    func test_create_case_opens_presenter() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset"]
        app.launch()

        let newButton = app.buttons["case.new"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 10))
        newButton.tap()

        // The text field lives inside an alert; query it through the alert scope
        // (identifiers on alert text fields don't surface at the app level).
        let alert = app.alerts["New Case"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let nameField = alert.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Smoke Case")
        alert.buttons["Create"].tap()

        // The new case opens into the presenter — the Import button is only enabled
        // once a case is loaded, so its presence proves the case opened.
        let importButton = app.buttons["toolbar.import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 10))
        XCTAssertTrue(importButton.isEnabled)
    }
}
