import XCTest

final class VideoFlowUITest: XCTestCase {
    func test_video_transport_and_publish() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        // Wait for the case to load, then select the video exhibit. D-009 is the only row
        // in its (Joint) section, so its static text surfaces reliably.
        let sidebar = app.collectionViews["exhibit.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))

        let videoRow = app.staticTexts["D-009"]
        XCTAssertTrue(videoRow.waitForExistence(timeout: 10))
        videoRow.tap()

        // The transport controls render only for video exhibits, so their presence proves
        // the video exhibit was selected. (The AVPlayerLayer surface itself is not an
        // accessibility element.)
        let playPause = app.buttons["video.playpause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 10))
        XCTAssertEqual(playPause.value as? String, "paused")
        playPause.tap()
        XCTAssertEqual(playPause.value as? String, "playing")
        playPause.tap()
        XCTAssertEqual(playPause.value as? String, "paused")

        // Clip controls are addressable and don't crash the app.
        app.buttons["video.setin"].tap()
        app.buttons["video.setout"].tap()
        app.buttons["video.playclip"].tap()
        app.buttons["video.clearclip"].tap()

        // Publishing an admitted video is allowed and leaves the UI responsive.
        // (The jury surface renders on a separate external-display scene that is not
        // hosted in the single-window UI-test runner; the publish gate itself is
        // covered by AppStateTests.)
        let publish = app.buttons["toolbar.publish"]
        XCTAssertTrue(publish.isEnabled)
        publish.tap()
        XCTAssertTrue(playPause.isHittable)
    }
}
