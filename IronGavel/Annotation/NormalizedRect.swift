import CoreGraphics
import Foundation

struct NormalizedRect: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
    var w: CGFloat
    var h: CGFloat

    init(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    init(cgRect: CGRect, in viewSize: CGSize) {
        self.x = cgRect.minX / viewSize.width
        self.y = cgRect.minY / viewSize.height
        self.w = cgRect.width / viewSize.width
        self.h = cgRect.height / viewSize.height
    }

    func toCGRect(in viewSize: CGSize) -> CGRect {
        CGRect(x: x * viewSize.width,
               y: y * viewSize.height,
               width: w * viewSize.width,
               height: h * viewSize.height)
    }

    func clamped() -> NormalizedRect {
        let cx = max(0, min(1, x))
        let cy = max(0, min(1, y))
        var cw = max(0, w)
        var ch = max(0, h)
        if cx + cw > 1 { cw = 1 - cx }
        if cy + ch > 1 { ch = 1 - cy }
        return NormalizedRect(x: cx, y: cy, w: cw, h: ch)
    }
}
