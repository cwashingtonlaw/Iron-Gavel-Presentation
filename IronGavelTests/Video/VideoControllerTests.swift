import XCTest
import CoreMedia
@testable import IronGavel

@MainActor
final class VideoControllerTests: XCTestCase {
    private func t(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

    func test_load_sets_url_and_resets_state() throws {
        let url: URL
        do { url = try TestVideoFactory.makeShortVideo() }
        catch { throw XCTSkip("video fixture unavailable: \(error)") }
        defer { try? FileManager.default.removeItem(at: url) }

        let c = VideoController()
        c.load(url: url)
        XCTAssertEqual(c.url, url)
        XCTAssertFalse(c.isPlaying)
        XCTAssertEqual(c.currentTime, .zero)
        XCTAssertFalse(c.clip.isValid)
    }

    func test_toggle_flips_isPlaying() {
        let c = VideoController()
        XCTAssertFalse(c.isPlaying)
        c.toggle(); XCTAssertTrue(c.isPlaying)
        c.toggle(); XCTAssertFalse(c.isPlaying)
    }

    func test_set_in_out_builds_valid_clip() {
        let c = VideoController()
        c.seek(to: t(1)); c.setIn()
        c.seek(to: t(3)); c.setOut()
        XCTAssertEqual(c.clip.start, t(1))
        XCTAssertEqual(c.clip.end, t(3))
        XCTAssertTrue(c.clip.isValid)
    }

    func test_clear_clip_resets_markers() {
        let c = VideoController()
        c.seek(to: t(1)); c.setIn()
        c.seek(to: t(3)); c.setOut()
        c.clearClip()
        XCTAssertFalse(c.clip.isValid)
        XCTAssertNil(c.clip.start)
        XCTAssertNil(c.clip.end)
    }

    func test_play_clip_with_no_valid_range_is_noop() {
        let c = VideoController()
        c.playClip()
        XCTAssertFalse(c.isPlaying)
    }

    func test_play_clip_seeks_to_start_and_plays() {
        let c = VideoController()
        c.seek(to: t(1)); c.setIn()
        c.seek(to: t(3)); c.setOut()
        c.seek(to: t(5))
        c.playClip()
        XCTAssertEqual(c.currentTime, t(1))
        XCTAssertTrue(c.isPlaying)
    }

    func test_seek_clamps_negative_to_zero() {
        let c = VideoController()
        c.seek(to: t(-2))
        XCTAssertEqual(c.currentTime, .zero)
    }

    func test_set_volume_clamps_to_unit_range() {
        let c = VideoController()
        c.setVolume(0.5)
        XCTAssertEqual(c.volume, 0.5, accuracy: 0.0001)
        c.setVolume(-1)
        XCTAssertEqual(c.volume, 0)
        c.setVolume(2)
        XCTAssertEqual(c.volume, 1)
    }

    func test_toggle_mute_flips_state() {
        let c = VideoController()
        XCTAssertFalse(c.isMuted)
        c.toggleMute(); XCTAssertTrue(c.isMuted)
        c.toggleMute(); XCTAssertFalse(c.isMuted)
    }

    func test_on_frame_change_fires_on_second_boundary_only() {
        let c = VideoController()
        var seconds: [Int] = []
        c.onFrameChange = { seconds.append($0) }
        c.seek(to: t(0.2))   // second 0 (baseline -1) -> fires 0
        c.seek(to: t(0.7))   // still second 0, no fire
        c.seek(to: t(1.3))   // second 1, fires 1
        c.seek(to: t(2.0))   // second 2, fires 2
        XCTAssertEqual(seconds, [0, 1, 2])
    }
}
