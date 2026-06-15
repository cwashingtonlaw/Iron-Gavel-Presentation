import SwiftUI

@main
struct IronGavelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            PresenterScene()
                .environment(state)
                .onAppear {
                    JurySceneDelegate.sharedState = state
                    loadUITestFixtureIfRequested()
                }
        }
    }

    private func loadUITestFixtureIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--ui-test-fixture") else { return }
        guard let url = Bundle.main.url(forResource: "ui-test-exhibits", withExtension: "json"),
              let kase = try? JSONDecoder().decode(Case.self, from: Data(contentsOf: url)) else {
            return
        }
        state.apply(case: kase, folder: url.deletingLastPathComponent())
    }
}
