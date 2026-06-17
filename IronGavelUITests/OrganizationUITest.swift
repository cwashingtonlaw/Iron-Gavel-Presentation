import XCTest

final class OrganizationUITest: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()
        return app
    }

    func test_mark_key_star_is_reachable_and_responsive() {
        // The key flag's persistence + state update is verified by CaseControllerTests;
        // here we just confirm the preview star is reachable and the app stays responsive.
        let app = launch()
        let sidebar = app.collectionViews["exhibit.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))
        app.staticTexts["D-001"].tap()

        let star = app.buttons["exhibit.key"]
        XCTAssertTrue(star.waitForExistence(timeout: 5))
        star.tap()
        XCTAssertTrue(app.buttons["exhibit.edit"].waitForExistence(timeout: 5))
    }

    func test_grouping_toggle_switches_to_folder() {
        let app = launch()
        let grouping = app.segmentedControls["sidebar.grouping"]
        XCTAssertTrue(grouping.waitForExistence(timeout: 10))
        grouping.buttons["Folder"].tap()
        XCTAssertTrue(app.staticTexts["UNFILED"].waitForExistence(timeout: 5))
    }

    func test_doc_search_sheet_opens() {
        let app = launch()
        let button = app.buttons["toolbar.docSearch"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(app.textFields["docsearch.field"].waitForExistence(timeout: 5))
    }
}
