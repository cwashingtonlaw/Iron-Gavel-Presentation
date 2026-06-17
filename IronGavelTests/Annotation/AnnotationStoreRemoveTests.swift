import XCTest
@testable import IronGavel

@MainActor
final class AnnotationStoreRemoveTests: XCTestCase {
    private func callout(_ tag: CGFloat) -> Annotation {
        Annotation(tool: .callout, color: .red,
                   bounds: NormalizedRect(x: tag, y: tag, w: 0.1, h: 0.1),
                   calloutSource: NormalizedRect(x: 0, y: 0, w: 0.1, h: 0.1))
    }

    func test_remove_deletes_only_target_and_bumps_version() {
        let store = AnnotationStore()
        var changed: [String] = []
        store.onChange = { changed.append($0) }
        let a = callout(0.1); let b = callout(0.2)
        store.add(a, exhibitId: "D-001", page: 0)
        store.add(b, exhibitId: "D-001", page: 0)
        let v0 = store.pageVersion(exhibitId: "D-001", page: 0)

        store.remove(id: a.id, exhibitId: "D-001", page: 0)

        let remaining = store.annotations(exhibitId: "D-001", page: 0)
        XCTAssertEqual(remaining.map(\.id), [b.id])
        XCTAssertGreaterThan(store.pageVersion(exhibitId: "D-001", page: 0), v0)
        XCTAssertEqual(changed.last, "D-001")
    }

    func test_remove_unknown_id_is_noop() {
        let store = AnnotationStore()
        let a = callout(0.1)
        store.add(a, exhibitId: "D-001", page: 0)
        store.remove(id: UUID(), exhibitId: "D-001", page: 0)
        XCTAssertEqual(store.annotations(exhibitId: "D-001", page: 0).count, 1)
    }

    func test_two_callouts_coexist() {
        let store = AnnotationStore()
        store.add(callout(0.1), exhibitId: "D-001", page: 0)
        store.add(callout(0.2), exhibitId: "D-001", page: 0)
        let list = store.annotations(exhibitId: "D-001", page: 0)
        XCTAssertEqual(list.filter { $0.tool == .callout }.count, 2)
    }
}
