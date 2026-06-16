import XCTest
@testable import IronGavel

final class TrialRecordTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("igrec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    private func ex(_ id: String, party: Party, status: ExhibitStatus, desc: String = "d",
                    witness: String? = nil, bates: String? = nil,
                    objection: String? = nil, ruling: String? = nil) -> Exhibit {
        Exhibit(id: id, party: party, description: desc, file: "f.pdf", witness: witness,
                bates: bates, status: status, mediaType: .pdf, objection: objection, ruling: ruling, notes: nil)
    }
    private func makeCase(_ exhibits: [Exhibit]) -> Case {
        Case(contractVersion: "1.0", case: .init(caption: "State v. Doe", docket: "D", court: "C"),
             generated: "2026-06-16T00:00:00-05:00", pathBase: "p", exhibits: exhibits)
    }

    // MARK: ExhibitListExporter

    func test_csv_has_header_and_sorted_rows() {
        let kase = makeCase([
            ex("S-014", party: .state, status: .pending, desc: "Body cam"),
            ex("D-001", party: .defense, status: .admitted, desc: "Photo", witness: "Off. Smith", bates: "DEF0001")
        ])
        let csv = ExhibitListExporter().csv(for: kase)
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.first, "ID,Party,Description,Witness,Bates,Status,Objection,Ruling")
        // Defense sorts before State.
        XCTAssertTrue(lines[1].hasPrefix("D-001,Defense,Photo,Off. Smith,DEF0001,admitted"))
        XCTAssertTrue(lines[2].hasPrefix("S-014,State,Body cam"))
    }

    func test_csv_escapes_commas() {
        let kase = makeCase([ex("D-001", party: .defense, status: .admitted, desc: "Photo, wide angle")])
        let csv = ExhibitListExporter().csv(for: kase)
        XCTAssertTrue(csv.contains("\"Photo, wide angle\""))
    }

    func test_exporter_writes_file() throws {
        let kase = makeCase([ex("D-001", party: .defense, status: .admitted)])
        let url = try ExhibitListExporter().write(kase, to: tmp)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.lastPathComponent, "exhibit-list.csv")
    }

    // MARK: AuditLog

    func test_audit_appends_and_loads_in_order() throws {
        let log = AuditLog()
        try log.append(.init(time: "2026-06-16T10:00:00Z", kind: "publish", detail: "D-001"), to: tmp)
        try log.append(.init(time: "2026-06-16T10:01:00Z", kind: "blank", detail: ""), to: tmp)
        let events = log.load(from: tmp)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].kind, "publish")
        XCTAssertEqual(events[0].detail, "D-001")
        XCTAssertEqual(events[1].kind, "blank")
    }

    func test_audit_load_empty_when_absent() {
        XCTAssertEqual(AuditLog().load(from: tmp).count, 0)
    }

    // MARK: DispositionLog

    func test_disposition_append_and_load() throws {
        let log = DispositionLog()
        try log.append(.init(time: "2026-06-16T10:00:00Z", exhibitId: "D-001",
                             objection: "Hearsay", ruling: "Overruled", note: ""), to: tmp)
        try log.append(.init(time: "2026-06-16T10:05:00Z", exhibitId: "S-014",
                             objection: "Foundation", ruling: "Sustained", note: "re-offer later"), to: tmp)
        let entries = log.load(from: tmp)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].exhibitId, "D-001")
        XCTAssertEqual(entries[1].ruling, "Sustained")
    }
}
