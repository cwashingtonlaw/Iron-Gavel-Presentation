import XCTest
@testable import IronGavel

@MainActor
final class AppStateTests: XCTestCase {
    private func exhibit(_ id: String, status: ExhibitStatus, file: String = "f.pdf") -> Exhibit {
        Exhibit(
            id: id, party: .defense, description: id,
            file: file, witness: nil, bates: nil,
            status: status, mediaType: .pdf,
            objection: nil, ruling: nil, notes: nil
        )
    }

    private func makeCase(_ exhibits: [Exhibit]) -> Case {
        Case(
            contractVersion: "1.0",
            case: .init(caption: "X", docket: "Y", court: "Z"),
            generated: "2026-06-14T00:00:00-05:00",
            pathBase: "sidecar_dir",
            exhibits: exhibits
        )
    }

    func test_publish_admitted_exhibit_sets_jury_display() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()
        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 0, annotationsVersion: 0))
    }

    func test_publish_non_admitted_exhibit_is_no_op() {
        let pending = exhibit("S-014", status: .pending)
        let state = AppState()
        state.apply(case: makeCase([pending]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(pending)
        state.publishSelected()
        XCTAssertEqual(state.juryDisplay, .empty)
    }

    func test_blank_then_restore_returns_to_last_published() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()
        state.setPage(3)
        state.blank()
        XCTAssertEqual(state.juryDisplay, .blank)
        state.restore()
        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 3, annotationsVersion: 0))
    }

    func test_status_downgrade_on_published_exhibit_auto_blanks() {
        let admitted = exhibit("D-001", status: .admitted)
        let downgraded = exhibit("D-001", status: .objected)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()

        state.apply(case: makeCase([downgraded]), folder: URL(fileURLWithPath: "/tmp"))

        XCTAssertEqual(state.juryDisplay, .blank)
        XCTAssertNotNil(state.lastStatusBanner)
        XCTAssertTrue(state.lastStatusBanner?.contains("D-001") ?? false)
    }

    func test_status_change_on_non_published_exhibit_does_not_blank() {
        let admitted = exhibit("D-001", status: .admitted)
        let other = exhibit("S-014", status: .pending)
        let otherChanged = exhibit("S-014", status: .objected)
        let state = AppState()
        state.apply(case: makeCase([admitted, other]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()

        state.apply(case: makeCase([admitted, otherChanged]), folder: URL(fileURLWithPath: "/tmp"))

        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 0, annotationsVersion: 0))
        XCTAssertNil(state.lastStatusBanner)
    }

    func test_annotation_mutation_on_published_exhibit_bumps_jury_version() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()

        let v0 = state.juryDisplay.annotationsVersion ?? -1

        let mark = Annotation(tool: .highlight, color: .yellow,
                              bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.05))
        state.annotationStore.add(mark, exhibitId: "D-001", page: 0)

        let v1 = state.juryDisplay.annotationsVersion ?? -1
        XCTAssertGreaterThan(v1, v0)
    }

    func test_annotation_mutation_on_non_published_exhibit_does_not_change_jury() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()

        let before = state.juryDisplay

        let mark = Annotation(tool: .highlight, color: .yellow,
                              bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.05))
        state.annotationStore.add(mark, exhibitId: "S-999", page: 0)

        XCTAssertEqual(state.juryDisplay, before)
    }

    func test_annotation_change_writes_to_disk_after_debounce() async throws {
        let tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("iron-gavel-state-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: tmpRoot)
        state.select(admitted)

        let mark = Annotation(tool: .highlight, color: .yellow,
                              bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.05))
        state.annotationStore.add(mark, exhibitId: "D-001", page: 0)

        try await Task.sleep(nanoseconds: 800_000_000)

        let saved = tmpRoot.appendingPathComponent("Trial/Annotations/D-001.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.path),
                      "expected debounced save at \(saved.path)")
    }
}
