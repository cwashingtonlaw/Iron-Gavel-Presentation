import XCTest
@testable import IronGavel

final class RecordExporterTests: XCTestCase {
    private func tempCase() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("igrec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Trial/Annotated"),
                                                withIntermediateDirectories: true)
        return root
    }

    private func makeCase() -> Case {
        let ex = Exhibit(id: "D-001", party: .defense, description: "Photo", file: "Exhibits/p.pdf",
                         witness: "Smith", bates: nil, status: .admitted, mediaType: .pdf,
                         objection: nil, ruling: nil, notes: nil)
        return Case(contractVersion: "1.0", case: .init(caption: "State v. Doe", docket: "D", court: "C"),
                    generated: "t", pathBase: "sidecar_dir", exhibits: [ex])
    }

    func test_assembles_record_folder_with_all_artifacts() throws {
        let root = try tempCase(); defer { try? FileManager.default.removeItem(at: root) }
        let trial = root.appendingPathComponent("Trial")

        // Seed sidecars the exporter should copy.
        try Data("event\n".utf8).write(to: trial.appendingPathComponent(AuditLog.fileName))
        try Data("{}".utf8).write(to: trial.appendingPathComponent(DispositionLog.fileName))
        try Data("%PDF-1.4".utf8).write(to: trial.appendingPathComponent("Annotated/D-001-p0.pdf"))

        let recordDir = try RecordExporter().export(kase: makeCase(), caseFolder: root, stamp: "2026-06-17")
        let fm = FileManager.default

        XCTAssertEqual(recordDir.lastPathComponent, "Record-2026-06-17")
        XCTAssertTrue(fm.fileExists(atPath: recordDir.appendingPathComponent(ExhibitListExporter.fileName).path))
        XCTAssertTrue(fm.fileExists(atPath: recordDir.appendingPathComponent(AuditLog.fileName).path))
        XCTAssertTrue(fm.fileExists(atPath: recordDir.appendingPathComponent(DispositionLog.fileName).path))
        XCTAssertTrue(fm.fileExists(atPath: recordDir.appendingPathComponent("Annotated/D-001-p0.pdf").path))

        // The CSV is freshly generated from the case, not copied.
        let csv = try String(contentsOf: recordDir.appendingPathComponent(ExhibitListExporter.fileName), encoding: .utf8)
        XCTAssertTrue(csv.contains("D-001"))
        XCTAssertTrue(csv.contains("Smith"))
    }

    func test_succeeds_when_optional_sidecars_absent() throws {
        let root = try tempCase(); defer { try? FileManager.default.removeItem(at: root) }
        // No audit log, dispositions, or annotated PDFs seeded.
        let recordDir = try RecordExporter().export(kase: makeCase(), caseFolder: root, stamp: "2026-06-17")
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: recordDir.appendingPathComponent(ExhibitListExporter.fileName).path))
        XCTAssertFalse(fm.fileExists(atPath: recordDir.appendingPathComponent(AuditLog.fileName).path))
    }
}
