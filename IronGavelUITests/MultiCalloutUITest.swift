import XCTest

final class MultiCalloutUITest: XCTestCase {
    func test_two_callouts_render_and_one_deletes() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "--ui-test-seed-callouts"]
        app.launch()

        // The ancestor 'preview.pane' identifier overrides the badge identifier (a SwiftUI
        // quirk), so query the delete badges by their accessibility label.
        let badges = app.buttons.matching(NSPredicate(format: "label == %@", "Delete callout"))
        XCTAssertTrue(badges.element(boundBy: 0).waitForExistence(timeout: 10))
        XCTAssertEqual(badges.count, 2)

        badges.element(boundBy: 0).tap()

        let remaining = app.buttons.matching(NSPredicate(format: "label == %@", "Delete callout"))
        XCTAssertTrue(remaining.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertEqual(remaining.count, 1)
    }
}
