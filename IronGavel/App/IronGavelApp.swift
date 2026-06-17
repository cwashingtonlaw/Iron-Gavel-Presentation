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
              let data = try? Data(contentsOf: url),
              let kase = try? JSONDecoder().decode(Case.self, from: data) else {
            return
        }
        // Copy the fixture into a writable temp folder (the app bundle is read-only) so
        // in-app edits — key flag, folder, status — can persist during UI tests.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("UITestCase")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appendingPathComponent("exhibits.json"))
        state.apply(case: kase, folder: folder)
    }
}
