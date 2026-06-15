import UIKit
import SwiftUI

@MainActor
final class JurySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    static var sharedState: AppState?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let root: AnyView
        if let state = JurySceneDelegate.sharedState {
            root = AnyView(JuryView().environment(state))
        } else {
            root = AnyView(BlankView())
        }
        window.rootViewController = UIHostingController(rootView: root)
        window.isHidden = false
        self.window = window
        JurySceneDelegate.sharedState?.externalConnected = true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        JurySceneDelegate.sharedState?.externalConnected = false
    }
}
