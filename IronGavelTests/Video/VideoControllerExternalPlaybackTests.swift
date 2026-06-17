import XCTest
import AVFoundation
@testable import IronGavel

@MainActor
final class VideoControllerExternalPlaybackTests: XCTestCase {
    func test_player_does_not_hand_off_video_to_airplay() {
        // We render video into the jury AVPlayerLayer on the external screen;
        // AVPlayer handoff (allowsExternalPlayback) would yank it out of our layout.
        let controller = VideoController()
        XCTAssertFalse(controller.player.allowsExternalPlayback)
    }
}
