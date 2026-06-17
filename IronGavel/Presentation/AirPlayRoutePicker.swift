import SwiftUI
import AVKit

/// Presents the system AirPlay route chooser so the attorney can pick the
/// courtroom receiver in-app. Screen output then flows through the existing
/// external-display jury scene.
struct AirPlayRoutePicker: UIViewRepresentable {
    var tint: UIColor = .label

    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.activeTintColor = tint
        v.tintColor = tint
        v.prioritizesVideoDevices = true
        v.accessibilityIdentifier = "airplay.routePicker"
        return v
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.activeTintColor = tint
        uiView.tintColor = tint
    }
}
