import XCTest
@testable import IronGavel

final class WhiteboardExporterTests: XCTestCase {
    func test_export_writes_nonempty_pdf() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wb-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let ann = [Annotation(tool: .highlight, color: .yellow,
                              bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.3, h: 0.2))]
        let out = tmp.appendingPathComponent("board.pdf")
        try WhiteboardExporter().export(annotations: ann, to: out)

        let data = try Data(contentsOf: out)
        XCTAssertGreaterThan(data.count, 0)
    }
}
