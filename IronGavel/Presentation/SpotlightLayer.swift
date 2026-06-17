import SwiftUI

/// Dims everything except a normalized cut-out region, focusing the room on one area of
/// the exhibit. Rendered identically on the presenter and the jury so it mirrors live.
struct SpotlightLayer: View {
    @Environment(AppState.self) private var state

    var body: some View {
        GeometryReader { geo in
            if let region = state.spotlight {
                let rect = region.toCGRect(in: geo.size)
                Rectangle()
                    .fill(Color.black.opacity(0.62))
                    .reverseMask {
                        RoundedRectangle(cornerRadius: 6)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.Palette.live.opacity(0.9), lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Presenter drag surface: a finger drag marquees the spotlight region. A near-zero drag
/// (a tap) clears the spotlight.
struct SpotlightDragSurface: View {
    @Environment(AppState.self) private var state
    @State private var start: CGPoint?

    var body: some View {
        GeometryReader { geo in
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if start == nil { start = value.startLocation }
                            guard let s = start else { return }
                            let rect = CGRect(
                                x: min(s.x, value.location.x),
                                y: min(s.y, value.location.y),
                                width: abs(value.location.x - s.x),
                                height: abs(value.location.y - s.y))
                            if rect.width > 8, rect.height > 8 {
                                state.setSpotlight(NormalizedRect(cgRect: rect, in: geo.size))
                            }
                        }
                        .onEnded { value in
                            defer { start = nil }
                            let s = start ?? value.startLocation
                            let dx = abs(value.location.x - s.x)
                            let dy = abs(value.location.y - s.y)
                            if dx < 8, dy < 8 { state.clearSpotlight() }
                        }
                )
        }
        .accessibilityIdentifier("spotlight.surface")
    }
}

private extension View {
    /// Punches a hole in `self` using the inverse of the given mask content.
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay { mask().blendMode(.destinationOut) }
        }
    }
}
