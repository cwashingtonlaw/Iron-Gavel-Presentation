import AVFoundation
import SwiftUI
import UIKit

/// Display-only jury mirror of the shared AVPlayer. Reuses PlayerLayerView.
struct VideoJuryView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let v = PlayerLayerView()
        v.backgroundColor = .black
        v.playerLayer.videoGravity = .resizeAspect
        v.playerLayer.player = player
        v.accessibilityIdentifier = "video.jury"
        return v
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}
