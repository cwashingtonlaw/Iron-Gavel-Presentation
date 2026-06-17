import XCTest
@testable import IronGavel

final class JuryDisplayWhiteboardTests: XCTestCase {
    func test_whiteboard_equatable_by_version() {
        XCTAssertEqual(JuryDisplay.whiteboard(annotationsVersion: 1),
                       JuryDisplay.whiteboard(annotationsVersion: 1))
        XCTAssertNotEqual(JuryDisplay.whiteboard(annotationsVersion: 1),
                          JuryDisplay.whiteboard(annotationsVersion: 2))
    }
}

@MainActor
final class AppStateWhiteboardTests: XCTestCase {
    func test_showWhiteboard_publishes_and_resets_viewport() {
        let state = AppState()
        state.setJuryViewport(NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.2))
        state.showWhiteboard()
        guard case .whiteboard = state.juryDisplay else { return XCTFail("not whiteboard") }
        XCTAssertTrue(state.juryViewport.isFull)
    }

    func test_drawing_on_whiteboard_bumps_published_version() {
        let state = AppState()
        state.showWhiteboard()
        let v0 = state.juryDisplay.annotationsVersion ?? -1
        state.annotationStore.add(
            Annotation(tool: .freehand, color: .red, inkDataBase64: Data().base64EncodedString()),
            exhibitId: AppState.whiteboardExhibitId, page: 0)
        let v1 = state.juryDisplay.annotationsVersion ?? -1
        XCTAssertGreaterThan(v1, v0)
    }

    func test_clearWhiteboard_empties_page() {
        let state = AppState()
        state.showWhiteboard()
        state.annotationStore.add(
            Annotation(tool: .freehand, color: .red, inkDataBase64: Data().base64EncodedString()),
            exhibitId: AppState.whiteboardExhibitId, page: 0)
        state.clearWhiteboard()
        XCTAssertTrue(state.annotationStore.annotations(exhibitId: AppState.whiteboardExhibitId, page: 0).isEmpty)
    }
}

@MainActor
final class AppStateAirPlayTests: XCTestCase {
    func test_mirroring_suspected_truth_table() {
        let state = AppState()
        state.screenCount = 1; state.externalConnected = false
        XCTAssertFalse(state.airPlayMirroringSuspected)

        state.screenCount = 2; state.externalConnected = true
        XCTAssertFalse(state.airPlayMirroringSuspected)

        state.screenCount = 2; state.externalConnected = false
        XCTAssertTrue(state.airPlayMirroringSuspected)
    }
}
