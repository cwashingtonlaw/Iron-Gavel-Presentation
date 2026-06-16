import XCTest
import CoreMedia
@testable import IronGavel

final class ClipRangeTests: XCTestCase {
    private func t(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

    func test_empty_or_half_set_range_is_invalid() {
        XCTAssertFalse(ClipRange().isValid)
        XCTAssertFalse(ClipRange(start: t(1)).isValid)
        XCTAssertFalse(ClipRange(end: t(2)).isValid)
    }

    func test_start_before_end_is_valid() {
        XCTAssertTrue(ClipRange(start: t(1), end: t(2)).isValid)
    }

    func test_start_not_before_end_is_invalid() {
        XCTAssertFalse(ClipRange(start: t(2), end: t(2)).isValid)
        XCTAssertFalse(ClipRange(start: t(3), end: t(2)).isValid)
    }

    func test_contains_within_inclusive_bounds() {
        let r = ClipRange(start: t(1), end: t(3))
        XCTAssertTrue(r.contains(t(1)))
        XCTAssertTrue(r.contains(t(2)))
        XCTAssertTrue(r.contains(t(3)))
        XCTAssertFalse(r.contains(t(0.5)))
        XCTAssertFalse(r.contains(t(3.5)))
    }

    func test_contains_is_false_for_invalid_range() {
        XCTAssertFalse(ClipRange(start: t(1)).contains(t(1)))
    }

    func test_clamping_end_shrinks_to_duration() {
        let clamped = ClipRange(start: t(1), end: t(10)).clampingEnd(to: t(5))
        XCTAssertEqual(clamped.start, t(1))
        XCTAssertEqual(clamped.end, t(5))
    }

    func test_clamping_end_leaves_shorter_end_untouched() {
        XCTAssertEqual(ClipRange(start: t(1), end: t(3)).clampingEnd(to: t(5)).end, t(3))
    }
}
