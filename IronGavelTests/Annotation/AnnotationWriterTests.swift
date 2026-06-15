import XCTest
@testable import IronGavel

final class AnnotationWriterTests: XCTestCase {
    private var tmpRoot: URL!

    override func setUpWithError() throws {
        tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("iron-gavel-writer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpRoot)
    }

    private func sampleDoc() -> AnnotationDocument {
        AnnotationDocument(
            contractVersion: "1.0",
            exhibitId: "D-001",
            lastModified: "2026-06-15T03:00:00Z",
            pages: ["0": []]
        )
    }

    func test_writes_to_specified_folder_creating_missing_parent() throws {
        let nested = tmpRoot.appendingPathComponent("Trial/Annotations")
        let writer = AnnotationWriter()
        try writer.write(sampleDoc(), to: nested)
        let expected = nested.appendingPathComponent("D-001.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }

    func test_write_is_atomic_no_temp_file_left_behind() throws {
        let writer = AnnotationWriter()
        try writer.write(sampleDoc(), to: tmpRoot)
        let contents = try FileManager.default.contentsOfDirectory(atPath: tmpRoot.path)
        XCTAssertTrue(contents.contains("D-001.json"))
        XCTAssertFalse(contents.contains { $0.hasSuffix(".tmp") })
    }

    func test_round_trip_through_loader() throws {
        let writer = AnnotationWriter()
        let loader = AnnotationLoader()
        try writer.write(sampleDoc(), to: tmpRoot)
        let loaded = try loader.load(annotationsFolder: tmpRoot, exhibitId: "D-001")
        XCTAssertEqual(loaded, sampleDoc())
    }
}
