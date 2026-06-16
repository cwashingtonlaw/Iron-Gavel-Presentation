import SwiftUI

/// A transparent drag surface for marquee-selecting a region to zoom into.
/// Emits the selection as a NormalizedRect in container coordinates.
struct ZoomSelectionView: View {
    let onSelect: (NormalizedRect) -> Void
    @State private var start: CGPoint?
    @State private var current: CGPoint?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.001)
                if let r = selectionRect {
                    Rectangle()
                        .strokeBorder(Color.yellow, lineWidth: 2)
                        .background(Color.yellow.opacity(0.15))
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if start == nil { start = value.startLocation }
                        current = value.location
                    }
                    .onEnded { value in
                        let s = start ?? value.startLocation
                        let e = value.location
                        let w = geo.size.width
                        let h = geo.size.height
                        let nr = NormalizedRect(
                            x: min(s.x, e.x) / w,
                            y: min(s.y, e.y) / h,
                            w: abs(e.x - s.x) / w,
                            h: abs(e.y - s.y) / h
                        )
                        start = nil
                        current = nil
                        if nr.w > 0.02 && nr.h > 0.02 { onSelect(nr) }
                    }
            )
            .accessibilityIdentifier("zoom.selection")
        }
    }

    private var selectionRect: CGRect? {
        guard let s = start, let c = current else { return nil }
        return CGRect(x: min(s.x, c.x), y: min(s.y, c.y),
                      width: abs(c.x - s.x), height: abs(c.y - s.y))
    }
}
