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

        if ProcessInfo.processInfo.arguments.contains("--ui-test-seed-callouts"),
           let first = kase.exhibits.first(where: { $0.mediaType == .pdf && $0.status == .admitted }) {
            let src = NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.2)
            state.annotationStore.add(Annotation(tool: .callout, color: .red,
                bounds: NormalizedRect(x: 0.1, y: 0.5, w: 0.25, h: 0.25), calloutSource: src),
                exhibitId: first.id, page: 0)
            state.annotationStore.add(Annotation(tool: .callout, color: .blue,
                bounds: NormalizedRect(x: 0.6, y: 0.5, w: 0.25, h: 0.25), calloutSource: src),
                exhibitId: first.id, page: 0)
            state.select(first)
        }
    }
}
