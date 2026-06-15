import XCTest
@testable import IronGavel

@MainActor
final class AnnotationStoreTests: XCTestCase {
    private func highlight(_ id: UUID = UUID()) -> Annotation {
        Annotation(id: id, tool: .highlight, color: .yellow,
                   bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.05))
    }

    func test_add_appends_and_bumps_version() {
        let store = AnnotationStore()
        let v0 = store.pageVersion(exhibitId: "D-001", page: 0)
        store.add(highlight(), exhibitId: "D-001", page: 0)
        XCTAssertEqual(store.annotations(exhibitId: "D-001", page: 0).count, 1)
        XCTAssertGreaterThan(store.pageVersion(exhibitId: "D-001", page: 0), v0)
    }

    func test_undo_removes_last_added() {
        let store = AnnotationStore()
        let a = highlight(); let b = highlight()
        store.add(a, exhibitId: "D-001", page: 0)
        store.add(b, exhibitId: "D-001", page: 0)
        store.undo(exhibitId: "D-001", page: 0)
        let ids = store.annotations(exhibitId: "D-001", page: 0).map(\.id)
        XCTAssertEqual(ids, [a.id])
    }

    func test_clear_empties_page() {
        let store = AnnotationStore()
        store.add(highlight(), exhibitId: "D-001", page: 0)
        store.add(highlight(), exhibitId: "D-001", page: 0)
        store.clear(exhibitId: "D-001", page: 0)
        XCTAssertTrue(store.annotations(exhibitId: "D-001", page: 0).isEmpty)
    }

    func test_freehand_replace_keeps_single_annotation_per_page() {
        let store = AnnotationStore()
        let f1 = Annotation(tool: .freehand, color: .blue, inkDataBase64: "A")
        let f2 = Annotation(tool: .freehand, color: .blue, inkDataBase64: "B")
        store.add(f1, exhibitId: "D-001", page: 0)
        store.add(f2, exhibitId: "D-001", page: 0)
        let freehands = store.annotations(exhibitId: "D-001", page: 0).filter { $0.tool == .freehand }
        XCTAssertEqual(freehands.count, 1)
        XCTAssertEqual(freehands.first?.inkDataBase64, "B")
    }

    func test_on_change_fires_for_each_mutation() {
        let store = AnnotationStore()
        var hits: [String] = []
        store.onChange = { hits.append($0) }
        store.add(highlight(), exhibitId: "D-001", page: 0)
        store.add(highlight(), exhibitId: "S-014", page: 1)
        store.undo(exhibitId: "D-001", page: 0)
        store.clear(exhibitId: "S-014", page: 1)
        XCTAssertEqual(hits, ["D-001", "S-014", "D-001", "S-014"])
    }

    func test_apply_document_replaces_in_memory_for_one_exhibit() {
        let store = AnnotationStore()
        store.add(highlight(), exhibitId: "D-001", page: 0)
        var doc = AnnotationDocument.empty(exhibitId: "D-001")
        doc.pages["0"] = [highlight()]
        doc.pages["1"] = [highlight()]
        store.apply(doc)
        XCTAssertEqual(store.annotations(exhibitId: "D-001", page: 0).count, 1)
        XCTAssertEqual(store.annotations(exhibitId: "D-001", page: 1).count, 1)
    }
}
