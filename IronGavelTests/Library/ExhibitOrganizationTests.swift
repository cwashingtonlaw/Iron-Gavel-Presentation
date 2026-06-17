import XCTest
import PDFKit
import UIKit
@testable import IronGavel

// MARK: - shared helpers

private func orgTempDir() throws -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("igorg-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}

private func makeExhibit(id: String, party: Party = .defense, status: ExhibitStatus = .admitted,
                         mediaType: MediaType = .pdf, file: String = "Exhibits/x.pdf",
                         isKey: Bool = false, folder: String? = nil, witness: String? = nil) -> Exhibit {
    Exhibit(id: id, party: party, description: "desc-\(id)", file: file, witness: witness, bates: nil,
            status: status, mediaType: mediaType, objection: nil, ruling: nil, notes: nil,
            exhibitNumber: nil, isKey: isKey, folder: folder)
}

// MARK: - Codable / back-compat

final class ExhibitCodableKeyFolderTests: XCTestCase {
    func test_decodes_manifest_without_key_or_folder_as_defaults() throws {
        let json = """
        {"id":"D-001","party":"Defense","description":"Photo","file":"Exhibits/p.pdf",
         "status":"admitted","media_type":"pdf"}
        """.data(using: .utf8)!
        let ex = try JSONDecoder().decode(Exhibit.self, from: json)
        XCTAssertFalse(ex.isKey)
        XCTAssertNil(ex.folder)
    }

    func test_round_trips_key_and_folder() throws {
        let ex = makeExhibit(id: "D-002", isKey: true, folder: "Witness A")
        let data = try JSONEncoder().encode(ex)
        let back = try JSONDecoder().decode(Exhibit.self, from: data)
        XCTAssertEqual(back, ex)
        let str = String(data: data, encoding: .utf8)!
        XCTAssertTrue(str.contains("\"is_key\""))
        XCTAssertTrue(str.contains("\"folder\""))
    }

    func test_full_case_round_trips_through_writer_and_loader() throws {
        let tmp = try orgTempDir(); defer { try? FileManager.default.removeItem(at: tmp) }
        let kase = Case(contractVersion: ContractVersion.supported,
                        case: .init(caption: "State v. Doe", docket: "D", court: "C"),
                        generated: "2026-06-16T00:00:00Z", pathBase: "sidecar_dir",
                        exhibits: [makeExhibit(id: "D-001", isKey: true, folder: "Topic 1"),
                                   makeExhibit(id: "D-002")])
        try CaseManifestWriter().write(kase, to: tmp)
        XCTAssertEqual(try CaseLoader().load(folderURL: tmp), kase)
    }
}

// MARK: - ExhibitMutator

final class ExhibitMutatorTests: XCTestCase {
    private func kase(_ exhibits: [Exhibit]) -> Case {
        Case(contractVersion: ContractVersion.supported,
             case: .init(caption: "C", docket: "D", court: "Ct"),
             generated: "t", pathBase: "sidecar_dir", exhibits: exhibits)
    }

    func test_toggleKey_flips_only_target() {
        let k = kase([makeExhibit(id: "A"), makeExhibit(id: "B")])
        let out = ExhibitMutator.toggleKey("A", in: k)
        XCTAssertTrue(out.exhibits[0].isKey)
        XCTAssertFalse(out.exhibits[1].isKey)
        let back = ExhibitMutator.toggleKey("A", in: out)
        XCTAssertFalse(back.exhibits[0].isKey)
    }

    func test_setFolder_sets_and_clears_target_only() {
        let k = kase([makeExhibit(id: "A"), makeExhibit(id: "B", folder: "Old")])
        let out = ExhibitMutator.setFolder("Witness A", for: "A", in: k)
        XCTAssertEqual(out.exhibits[0].folder, "Witness A")
        XCTAssertEqual(out.exhibits[1].folder, "Old")
        let cleared = ExhibitMutator.setFolder(nil, for: "B", in: out)
        XCTAssertNil(cleared.exhibits[1].folder)
    }

    func test_unknown_id_is_noop() {
        let k = kase([makeExhibit(id: "A")])
        XCTAssertEqual(ExhibitMutator.toggleKey("Z", in: k), k)
    }
}

// MARK: - ExhibitGrouping

final class ExhibitGroupingTests: XCTestCase {
    func test_party_mode_orders_by_party_allCases() {
        let exhibits = [makeExhibit(id: "S", party: .state), makeExhibit(id: "D", party: .defense)]
        let sections = ExhibitGrouping.sections(for: exhibits, mode: .party)
        XCTAssertEqual(sections.map(\.title), ["Defense", "State"])
        XCTAssertEqual(sections[0].exhibits.map(\.id), ["D"])
    }

    func test_folder_mode_groups_alphabetically_with_unfiled_last() {
        let exhibits = [makeExhibit(id: "A", folder: "Zeta"),
                        makeExhibit(id: "B", folder: "Alpha"),
                        makeExhibit(id: "C", folder: nil)]
        let sections = ExhibitGrouping.sections(for: exhibits, mode: .folder)
        XCTAssertEqual(sections.map(\.title), ["Alpha", "Zeta", "Unfiled"])
        XCTAssertEqual(sections[2].exhibits.map(\.id), ["C"])
    }

    func test_folder_mode_all_unfiled() {
        let sections = ExhibitGrouping.sections(for: [makeExhibit(id: "A")], mode: .folder)
        XCTAssertEqual(sections.map(\.title), ["Unfiled"])
    }

    func test_witness_mode_groups_alphabetically_with_no_witness_last() {
        let exhibits = [makeExhibit(id: "A", witness: "Smith"),
                        makeExhibit(id: "B", witness: "Adams"),
                        makeExhibit(id: "C", witness: nil)]
        let sections = ExhibitGrouping.sections(for: exhibits, mode: .witness)
        XCTAssertEqual(sections.map(\.title), ["Adams", "Smith", "No Witness"])
        XCTAssertEqual(sections[0].exhibits.map(\.id), ["B"])
        XCTAssertEqual(sections[2].exhibits.map(\.id), ["C"])
    }

    func test_witness_mode_all_no_witness() {
        let sections = ExhibitGrouping.sections(for: [makeExhibit(id: "A")], mode: .witness)
        XCTAssertEqual(sections.map(\.title), ["No Witness"])
    }
}

// MARK: - DocumentSearch

final class DocumentSearchTests: XCTestCase {
    private func makeTwoPagePDF(at url: URL) throws {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { ctx in
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 24)]
            ctx.beginPage()
            ("alpha intersection" as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: attrs)
            ctx.beginPage()
            ("bravo collision" as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: attrs)
        }
        try data.write(to: url)
    }

    func test_finds_term_on_second_page_with_zero_based_index() throws {
        let tmp = try orgTempDir(); defer { try? FileManager.default.removeItem(at: tmp) }
        let exhibitsDir = tmp.appendingPathComponent("Exhibits")
        try FileManager.default.createDirectory(at: exhibitsDir, withIntermediateDirectories: true)
        try makeTwoPagePDF(at: exhibitsDir.appendingPathComponent("doc.pdf"))

        let exhibit = makeExhibit(id: "D-001", mediaType: .pdf, file: "Exhibits/doc.pdf")
        let hits = DocumentSearch().search(query: "COLLISION", in: [exhibit], caseFolder: tmp) { url in
            PDFDocument(url: url)
        }
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].exhibitId, "D-001")
        XCTAssertEqual(hits[0].page, 1)
    }

    func test_skips_non_pdf_and_short_query() throws {
        let tmp = try orgTempDir(); defer { try? FileManager.default.removeItem(at: tmp) }
        let audio = makeExhibit(id: "A-001", mediaType: .audio, file: "Exhibits/c.m4a")
        XCTAssertTrue(DocumentSearch().search(query: "x", in: [audio], caseFolder: tmp) { _ in nil }.isEmpty)
        XCTAssertTrue(DocumentSearch().search(query: "anything", in: [audio], caseFolder: tmp) { _ in nil }.isEmpty)
    }

    func test_missing_document_is_skipped() throws {
        let tmp = try orgTempDir(); defer { try? FileManager.default.removeItem(at: tmp) }
        let exhibit = makeExhibit(id: "D-001", mediaType: .pdf, file: "Exhibits/missing.pdf")
        let hits = DocumentSearch().search(query: "alpha", in: [exhibit], caseFolder: tmp) { url in
            PDFDocument(url: url)
        }
        XCTAssertTrue(hits.isEmpty)
    }
}
