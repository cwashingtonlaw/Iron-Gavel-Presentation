import XCTest

final class ZoomFlowUITest: XCTestCase {
    func test_zoom_to_region_and_reset() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let sidebar = app.collectionViews["exhibit.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
        app.staticTexts["D-001"].tap()

        // Enter zoom mode and marquee-drag a region on the preview.
        let zoomToggle = app.buttons["zoom.toggle"]
        XCTAssertTrue(zoomToggle.waitForExistence(timeout: 5))
        zoomToggle.tap()

        let pane = app.otherElements.matching(identifier: "preview.pane").firstMatch
        XCTAssertTrue(pane.waitForExistence(timeout: 5))
        let start = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
        let end = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7))
        start.press(forDuration: 0.05, thenDragTo: end)

        // After zooming, a Reset Zoom control appears; tapping it returns to full view.
        let reset = app.buttons["zoom.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        XCTAssertTrue(app.buttons["zoom.toggle"].waitForExistence(timeout: 5))
    }
}
