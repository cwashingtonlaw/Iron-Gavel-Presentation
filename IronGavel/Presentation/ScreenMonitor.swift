import UIKit

/// Observes screen connect/disconnect and reports the current screen count.
/// Used to detect AirPlay/HDMI *mirroring* (a second screen with no jury scene).
@MainActor
final class ScreenMonitor {
    private var observers: [NSObjectProtocol] = []
    var onChange: ((Int) -> Void)?

    func start() {
        let nc = NotificationCenter.default
        for name in [UIScreen.didConnectNotification, UIScreen.didDisconnectNotification] {
            let token = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.onChange?(UIScreen.screens.count)
                }
            }
            observers.append(token)
        }
        onChange?(UIScreen.screens.count)
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
