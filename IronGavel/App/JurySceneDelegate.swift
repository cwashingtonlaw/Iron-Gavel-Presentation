import UIKit
import SwiftUI

@MainActor
final class JurySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let state = AppState.shared
        let window = UIWindow(windowScene: windowScene)
        // Always host JuryView with the shared state. On a (re)connect the view immediately
        // reflects whatever the jury was last showing, because juryDisplay lives on the
        // shared, observed state — no nil race, no permanent blank window.
        window.rootViewController = UIHostingController(rootView: JuryView().environment(state))
        window.isHidden = false
        self.window = window
        state.externalConnected = true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        AppState.shared.externalConnected = false
    }
}
