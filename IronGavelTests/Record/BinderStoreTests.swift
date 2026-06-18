import XCTest
@testable import IronGavel

final class BinderStoreTests: XCTestCase {
    private func tempCase() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("igbin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func test_missing_binder_loads_empty() throws {
        let root = try tempCase(); defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertTrue(BinderStore().load(from: root).isEmpty)
    }

    func test_round_trips_steps_in_order() throws {
        let root = try tempCase(); defer { try? FileManager.default.removeItem(at: root) }
        let steps = [BinderStep(exhibitId: "D-001", page: 0, id: "s1"),
                     BinderStep(exhibitId: "D-002", page: 3, id: "s2"),
                     BinderStep(exhibitId: "D-001", page: 5, id: "s3")]
        try BinderStore().save(steps, to: root)
        XCTAssertEqual(BinderStore().load(from: root), steps)
    }

    func test_corrupt_binder_loads_empty() throws {
        let root = try tempCase(); defer { try? FileManager.default.removeItem(at: root) }
        let dir = root.appendingPathComponent("Trial")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent(BinderStore.fileName))
        XCTAssertTrue(BinderStore().load(from: root).isEmpty)
    }
}
