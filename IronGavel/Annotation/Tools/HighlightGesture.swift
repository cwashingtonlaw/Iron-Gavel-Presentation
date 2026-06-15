import SwiftUI

struct HighlightGestureModifier: ViewModifier {
    let viewSize: CGSize
    let onCommit: (NormalizedRect) -> Void
    @State private var start: CGPoint?

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if start == nil { start = value.startLocation }
                    }
                    .onEnded { value in
                        defer { start = nil }
                        guard let s = start else { return }
                        let cg = CGRect(
                            x: min(s.x, value.location.x),
                            y: min(s.y, value.location.y),
                            width: abs(value.location.x - s.x),
                            height: abs(value.location.y - s.y)
                        )
                        let n = NormalizedRect(cgRect: cg, in: viewSize).clamped()
                        if n.w > 0.005 && n.h > 0.005 {
                            onCommit(n)
                        }
                    }
            )
    }
}
