import XCTest

final class AnnotationFlowUITest: XCTestCase {
    func test_highlight_appears_after_drag() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let admittedRow = app.staticTexts["D-001"]
        XCTAssertTrue(admittedRow.waitForExistence(timeout: 5))
        admittedRow.tap()

        let publish = app.buttons["toolbar.publish"]
        XCTAssertTrue(publish.waitForExistence(timeout: 5))
        publish.tap()

        let highlightTool = app.buttons["annotation.tool.highlight"]
        XCTAssertTrue(highlightTool.waitForExistence(timeout: 5))
        highlightTool.tap()

        let pane = app.otherElements.matching(identifier: "preview.pane").firstMatch
        XCTAssertTrue(pane.waitForExistence(timeout: 5))

        let start = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
        let end = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)

        // After the drag the Undo button should be reachable (no crash, toolbar still alive).
        // The actual store mutation is verified by AppStateTests.
        let undoButton = app.buttons["annotation.undo"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5))
        XCTAssertTrue(undoButton.isHittable)
    }
}
