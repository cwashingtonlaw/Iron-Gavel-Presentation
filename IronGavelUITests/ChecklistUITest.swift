import XCTest

final class ChecklistUITest: XCTestCase {
    func test_checklist_opens_and_item_toggles() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let button = app.buttons["toolbar.checklist"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()

        let firstItem = app.buttons["checklist.item.1"]
        XCTAssertTrue(firstItem.waitForExistence(timeout: 5))
        firstItem.tap()

        app.buttons["checklist.done"].tap()
        XCTAssertTrue(app.buttons["toolbar.checklist"].waitForExistence(timeout: 5))
    }
}
