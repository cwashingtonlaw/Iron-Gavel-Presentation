import CoreMedia
import Foundation

/// In/out markers for a video segment. Pure value type — no playback.
/// `CMTime` is Comparable, so `<`, `<=`, `>=`, and `min` work directly.
struct ClipRange: Equatable {
    var start: CMTime?
    var end: CMTime?

    init(start: CMTime? = nil, end: CMTime? = nil) {
        self.start = start
        self.end = end
    }

    /// Playable only when both ends are set and start strictly precedes end.
    var isValid: Bool {
        guard let start, let end else { return false }
        return start < end
    }

    func contains(_ time: CMTime) -> Bool {
        guard isValid, let start, let end else { return false }
        return time >= start && time <= end
    }

    /// A copy whose `end` is shrunk to not exceed `duration`.
    func clampingEnd(to duration: CMTime) -> ClipRange {
        guard let end else { return self }
        return ClipRange(start: start, end: min(end, duration))
    }
}
