import SwiftUI

/// Applies a JuryViewport to its content: a top-leading scale + offset so the
/// viewport's region fills the container. Used identically on the presenter and the
/// jury so a zoom on one mirrors the other.
struct ViewportContainer<Content: View>: View {
    let viewport: JuryViewport
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            content()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(viewport.scale, anchor: .topLeading)
                .offset(viewport.offset(in: geo.size))
        }
        .clipped()
    }
}
