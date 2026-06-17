import SwiftUI

/// Renders the laser dot at the shared normalized point. Used identically on the
/// presenter and the jury, so the pointer mirrors live.
struct LaserLayer: View {
    @Environment(AppState.self) private var state

    var body: some View {
        GeometryReader { geo in
            if let p = state.laserPoint {
                ZStack {
                    Circle().fill(Theme.Palette.live.opacity(0.28)).frame(width: 42, height: 42)
                    Circle().fill(Theme.Palette.live).frame(width: 18, height: 18)
                        .shadow(color: Theme.Palette.live.opacity(0.9), radius: 8)
                }
                .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Presenter drag surface: while active, a finger drag drives the laser; lifting clears it.
struct LaserDragSurface: View {
    @Environment(AppState.self) private var state

    var body: some View {
        GeometryReader { geo in
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            state.setLaser(CGPoint(
                                x: min(1, max(0, value.location.x / geo.size.width)),
                                y: min(1, max(0, value.location.y / geo.size.height))))
                        }
                        .onEnded { _ in state.clearLaser() }
                )
        }
        .accessibilityIdentifier("laser.surface")
    }
}
