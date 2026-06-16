import CoreGraphics
import Foundation

/// The sub-rectangle of an exhibit currently filling the display, normalized to 0..1.
/// Full view is (0,0,1,1). Both the presenter preview and the jury display apply the
/// SAME viewport, so zooming on the presenter mirrors exactly to the jury.
struct JuryViewport: Equatable {
    var region: NormalizedRect

    init(region: NormalizedRect = NormalizedRect(x: 0, y: 0, w: 1, h: 1)) {
        self.region = region
    }

    static let full = JuryViewport()

    var isFull: Bool {
        region.x <= 0.0001 && region.y <= 0.0001 && region.w >= 0.9999 && region.h >= 0.9999
    }

    /// Uniform scale that makes the region's width fill the container width.
    var scale: CGFloat {
        region.w > 0 ? 1 / region.w : 1
    }

    /// Offset (after a top-leading scaleEffect) that brings the region's origin to the
    /// container origin, so the zoomed region fills from the top-left.
    func offset(in size: CGSize) -> CGSize {
        let s = scale
        return CGSize(width: -region.x * size.width * s,
                      height: -region.y * size.height * s)
    }
}
