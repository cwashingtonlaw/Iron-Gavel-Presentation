import SwiftUI

@main
struct IronGavelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            PresenterScene()
                .environment(state)
                .onAppear { JurySceneDelegate.sharedState = state }
        }
    }
}
