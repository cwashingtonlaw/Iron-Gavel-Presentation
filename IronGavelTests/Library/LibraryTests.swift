import XCTest
@testable import IronGavel

// MARK: - MediaTypeDetector

final class MediaTypeDetectorTests: XCTestCase {
    func test_detects_each_class() {
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "PDF"), .pdf)
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "jpg"), .image)
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "heic"), .image)
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "mov"), .video)
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "m4a"), .audio)
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "xyz"), .unknown)
    }
    func test_detects_from_url() {
        XCTAssertEqual(MediaTypeDetector.detect(url: URL(fileURLWithPath: "/a/b.MP4")), .video)
    }
}

// MARK: - ExhibitIDAllocator

final class ExhibitIDAllocatorTests: XCTestCase {
    private func ex(_ id: String, _ party: Party) -> Exhibit {
        Exhibit(id: id, party: party, description: "x", file: "f", witness: nil, bates: nil,
                status: .pending, mediaType: .pdf, objection: nil, ruling: nil, notes: nil)
    }
    func test_first_id_per_party() {
        XCTAssertEqual(ExhibitIDAllocator.nextID(existing: [], party: .defense), "D-001")
        XCTAssertEqual(ExhibitIDAllocator.nextID(existing: [], party: .state), "S-001")
    }
    func test_next_after_existing() {
        let existing = [ex("D-001", .defense), ex("D-002", .defense), ex("S-005", .state)]
        XCTAssertEqual(ExhibitIDAllocator.nextID(existing: existing, party: .defense), "D-003")
        XCTAssertEqual(ExhibitIDAllocator.nextID(existing: existing, party: .state), "S-006")
        XCTAssertEqual(ExhibitIDAllocator.nextID(existing: existing, party: .joint), "J-001")
    }
}

// MARK: - shared helpers

private func tempDir() throws -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("iglib-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}

// MARK: - CaseManifestWriter

final class CaseManifestWriterTests: XCTestCase {
    func test_write_then_load_round_trips() throws {
        let tmp = try tempDir(); defer { try? FileManager.default.removeItem(at: tmp) }
        let exhibit = Exhibit(id: "D-001", party: .defense, description: "Photo", file: "Exhibits/p.pdf",
                              witness: nil, bates: nil, status: .admitted, mediaType: .pdf,
                              objection: nil, ruling: nil, notes: nil)
        let kase = Case(contractVersion: ContractVersion.supported,
                        case: .init(caption: "State v. Doe", docket: "D", court: "C"),
                        generated: "2026-06-16T00:00:00Z", pathBase: "sidecar_dir", exhibits: [exhibit])
        try CaseManifestWriter().write(kase, to: tmp)
        XCTAssertEqual(try CaseLoader().load(folderURL: tmp), kase)
    }
}

// MARK: - CaseStore

final class CaseStoreTests: XCTestCase {
    func test_create_lists_and_loads_empty_case() throws {
        let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let store = CaseStore(root: root)
        XCTAssertTrue(store.list().isEmpty)
        let folder = try store.create(name: "Doe", now: "2026-06-16T00:00:00Z")
        XCTAssertEqual(store.list(), ["Doe"])
        let loaded = try CaseLoader().load(folderURL: folder)
        XCTAssertEqual(loaded.exhibits.count, 0)
        XCTAssertEqual(loaded.`case`.caption, "Doe")
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Exhibits").path))
    }
    func test_delete_and_rename() throws {
        let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let store = CaseStore(root: root)
        _ = try store.create(name: "A", now: "t")
        try store.rename("A", to: "B")
        XCTAssertEqual(store.list(), ["B"])
        try store.delete(name: "B")
        XCTAssertTrue(store.list().isEmpty)
    }
}

// MARK: - ExhibitImporter

final class ExhibitImporterTests: XCTestCase {
    private func srcFile(_ name: String, in dir: URL, _ bytes: String = "x") throws -> URL {
        let u = dir.appendingPathComponent(name)
        try bytes.data(using: .utf8)!.write(to: u)
        return u
    }

    func test_import_copies_files_and_creates_exhibits() throws {
        let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let store = CaseStore(root: root.appendingPathComponent("Cases"))
        let folder = try store.create(name: "Doe", now: "t")
        let pdf = try srcFile("photo.pdf", in: root)
        let audio = try srcFile("call.m4a", in: root)

        let updated = try ExhibitImporter().importFiles([pdf, audio], into: folder)

        XCTAssertEqual(updated.exhibits.count, 2)
        XCTAssertEqual(updated.exhibits[0].id, "D-001")
        XCTAssertEqual(updated.exhibits[0].mediaType, .pdf)
        XCTAssertEqual(updated.exhibits[0].file, "Exhibits/photo.pdf")
        XCTAssertEqual(updated.exhibits[1].id, "D-002")
        XCTAssertEqual(updated.exhibits[1].mediaType, .audio)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Exhibits/photo.pdf").path))
        XCTAssertEqual(try CaseLoader().load(folderURL: folder).exhibits.count, 2)
    }

    func test_import_dedupes_duplicate_filenames() throws {
        let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let store = CaseStore(root: root.appendingPathComponent("Cases"))
        let folder = try store.create(name: "Doe", now: "t")
        _ = try ExhibitImporter().importFiles([try srcFile("dup.pdf", in: root, "a")], into: folder)
        let updated = try ExhibitImporter().importFiles([try srcFile("dup.pdf", in: root, "b")], into: folder)
        XCTAssertEqual(updated.exhibits.count, 2)
        XCTAssertEqual(updated.exhibits[1].file, "Exhibits/dup 2.pdf")
    }
}

// MARK: - CaseBackup

final class CaseBackupTests: XCTestCase {
    func test_backup_then_restore_round_trips() throws {
        let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let store = CaseStore(root: root.appendingPathComponent("Cases"))
        let folder = try store.create(name: "Doe", now: "t")
        let backupRoot = root.appendingPathComponent("Backups")

        let backup = try CaseBackup().backup(caseFolder: folder, to: backupRoot)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("exhibits.json").path))

        try store.delete(name: "Doe")
        XCTAssertTrue(store.list().isEmpty)
        _ = try CaseBackup().restore(from: backup, to: store.root)
        XCTAssertEqual(store.list(), ["Doe"])
    }
}
