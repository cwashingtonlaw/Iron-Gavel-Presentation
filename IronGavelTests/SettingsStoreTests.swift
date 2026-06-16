import XCTest
@testable import IronGavel

@MainActor
final class SettingsStoreTests: XCTestCase {
    private func suite() -> UserDefaults { UserDefaults(suiteName: "tier3-\(UUID().uuidString)")! }

    private func exhibit(_ id: String, status: ExhibitStatus) -> Exhibit {
        Exhibit(id: id, party: .defense, description: id, file: "f.pdf",
                witness: nil, bates: nil, status: status, mediaType: .pdf,
                objection: nil, ruling: nil, notes: nil)
    }
    private func makeCase(_ exhibits: [Exhibit]) -> Case {
        Case(contractVersion: "1.0", case: .init(caption: "X", docket: "Y", court: "Z"),
             generated: "2026-06-16T00:00:00-05:00", pathBase: "p", exhibits: exhibits)
    }

    func test_defaults() {
        let s = SettingsStore(defaults: suite())
        XCTAssertEqual(s.defaultAnnotationColor, .yellow)
        XCTAssertEqual(s.juryBackground, .black)
        XCTAssertFalse(s.juryShowExhibitBanner)
        XCTAssertTrue(s.autoBlankOnDowngrade)
        XCTAssertTrue(s.confirmationPromptsEnabled)
        XCTAssertEqual(s.highlightOpacity, 0.4, accuracy: 0.0001)
    }

    func test_persists_across_instances() {
        let d = suite()
        let s1 = SettingsStore(defaults: d)
        s1.juryBackground = .white
        s1.juryShowExhibitBanner = true
        s1.autoBlankOnDowngrade = false
        s1.defaultAnnotationColor = .red
        s1.highlightOpacity = 0.3

        let s2 = SettingsStore(defaults: d)
        XCTAssertEqual(s2.juryBackground, .white)
        XCTAssertTrue(s2.juryShowExhibitBanner)
        XCTAssertFalse(s2.autoBlankOnDowngrade)
        XCTAssertEqual(s2.defaultAnnotationColor, .red)
        XCTAssertEqual(s2.highlightOpacity, 0.3, accuracy: 0.0001)
    }

    func test_appstate_seeds_currentColor_from_settings() {
        let s = SettingsStore(defaults: suite())
        s.defaultAnnotationColor = .green
        let app = AppState(settings: s)
        XCTAssertEqual(app.currentColor, .green)
    }

    func test_autoBlank_off_keeps_jury_on_downgrade() {
        let s = SettingsStore(defaults: suite())
        s.autoBlankOnDowngrade = false
        let admitted = exhibit("D-001", status: .admitted)
        let downgraded = exhibit("D-001", status: .objected)

        let app = AppState(settings: s)
        app.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        app.select(admitted)
        app.publishSelected()
        app.apply(case: makeCase([downgraded]), folder: URL(fileURLWithPath: "/tmp"))

        // With auto-blank disabled, the jury stays on the (originally published) exhibit.
        XCTAssertEqual(app.juryDisplay, .exhibit(admitted, page: 0, annotationsVersion: 0))
        XCTAssertNil(app.lastStatusBanner)
    }

    func test_autoBlank_on_blanks_on_downgrade() {
        let s = SettingsStore(defaults: suite())
        XCTAssertTrue(s.autoBlankOnDowngrade)
        let admitted = exhibit("D-001", status: .admitted)
        let downgraded = exhibit("D-001", status: .objected)

        let app = AppState(settings: s)
        app.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        app.select(admitted)
        app.publishSelected()
        app.apply(case: makeCase([downgraded]), folder: URL(fileURLWithPath: "/tmp"))

        XCTAssertEqual(app.juryDisplay, .blank)
        XCTAssertNotNil(app.lastStatusBanner)
    }
}
