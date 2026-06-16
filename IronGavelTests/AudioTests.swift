import XCTest
import CoreMedia
@testable import IronGavel

final class AudioTests: XCTestCase {
    private func t(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

    func test_media_type_decodes_audio() throws {
        let json = #"["audio"]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([MediaType].self, from: json)
        XCTAssertEqual(decoded, [.audio])
        XCTAssertTrue(MediaType.allCases.contains(.audio))
    }

    func test_progress_zero_when_no_duration() {
        XCTAssertEqual(AudioProgress.fraction(current: t(5), duration: .zero), 0, accuracy: 0.0001)
    }

    func test_progress_half() {
        XCTAssertEqual(AudioProgress.fraction(current: t(30), duration: t(60)), 0.5, accuracy: 0.0001)
    }

    func test_progress_clamps_to_one() {
        XCTAssertEqual(AudioProgress.fraction(current: t(90), duration: t(60)), 1, accuracy: 0.0001)
    }

    func test_progress_clamps_negative_to_zero() {
        XCTAssertEqual(AudioProgress.fraction(current: t(-5), duration: t(60)), 0, accuracy: 0.0001)
    }

    func test_progress_handles_indefinite_duration() {
        XCTAssertEqual(AudioProgress.fraction(current: t(5), duration: .indefinite), 0, accuracy: 0.0001)
    }
}
