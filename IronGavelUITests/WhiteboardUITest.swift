import XCTest

final class WhiteboardUITest: XCTestCase {
    func test_open_whiteboard_and_show_to_jury() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let wb = app.buttons["toolbar.whiteboard"]
        XCTAssertTrue(wb.waitForExistence(timeout: 10))
        wb.tap()

        XCTAssertTrue(app.buttons["whiteboard.tool.freehand"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["whiteboard.clear"].exists)

        let show = app.buttons["whiteboard.showJury"]
        XCTAssertTrue(show.waitForExistence(timeout: 5))
        show.tap()
        XCTAssertTrue(app.buttons["whiteboard.hideJury"].waitForExistence(timeout: 5))
    }
}
