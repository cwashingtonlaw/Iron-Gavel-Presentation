import XCTest

final class AudioFlowUITest: XCTestCase {
    func test_audio_now_playing_and_transport() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let sidebar = app.collectionViews["exhibit.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))

        // Static-text existence for a lower-section row is snapshot-flaky in XCUITest; let
        // the row settle, then tap (tap has its own implicit wait) and prove selection via
        // the downstream now-playing card.
        let audioRow = app.staticTexts["A-001"]
        _ = audioRow.waitForExistence(timeout: 10)
        audioRow.tap()

        // Transport renders for audio (proves selection); the annotation toolbar does NOT
        // (audio is not annotatable) — together these uniquely identify an audio exhibit.
        let playPause = app.buttons["video.playpause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["annotation.tool.highlight"].exists)

        XCTAssertEqual(playPause.value as? String, "paused")
        playPause.tap()
        XCTAssertEqual(playPause.value as? String, "playing")
        playPause.tap()
        XCTAssertEqual(playPause.value as? String, "paused")

        let publish = app.buttons["toolbar.publish"]
        XCTAssertTrue(publish.isEnabled)
        publish.tap()
        XCTAssertTrue(playPause.isHittable)
    }
}
