import SwiftUI

struct CalloutGestureModifier: ViewModifier {
    let viewSize: CGSize
    let onCommit: (_ source: NormalizedRect, _ bounds: NormalizedRect) -> Void

    @State private var stage: Stage = .awaitingSource
    @State private var pendingSource: NormalizedRect?
    @State private var dragStart: CGPoint?

    enum Stage { case awaitingSource, awaitingBounds }

    func body(content: Content) -> some View {
        content
            .overlay(stagePreview)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragStart == nil { dragStart = value.startLocation }
                    }
                    .onEnded { value in
                        defer { dragStart = nil }
                        guard let s = dragStart else { return }
                        let cg = CGRect(
                            x: min(s.x, value.location.x),
                            y: min(s.y, value.location.y),
                            width: abs(value.location.x - s.x),
                            height: abs(value.location.y - s.y)
                        )
                        let n = NormalizedRect(cgRect: cg, in: viewSize).clamped()
                        guard n.w > 0.005, n.h > 0.005 else { return }
                        switch stage {
                        case .awaitingSource:
                            pendingSource = n
                            stage = .awaitingBounds
                        case .awaitingBounds:
                            if let src = pendingSource { onCommit(src, n) }
                            pendingSource = nil
                            stage = .awaitingSource
                        }
                    }
            )
    }

    @ViewBuilder
    private var stagePreview: some View {
        if let src = pendingSource, stage == .awaitingBounds {
            GeometryReader { geo in
                let r = src.toCGRect(in: geo.size)
                Rectangle()
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: r.width, height: r.height)
                    .position(x: r.midX, y: r.midY)
            }
        }
    }
}
