import XCTest
@testable import IronGavel

final class BookmarkStoreTests: XCTestCase {
    private let key = "test.bookmark.\(UUID().uuidString)"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "iron-gavel-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().description)
        defaults = nil
        super.tearDown()
    }

    func test_stores_and_retrieves_bookmark_data() throws {
        let store = BookmarkStore(defaults: defaults, key: key)
        let bookmark = Data([0x01, 0x02, 0x03])
        store.save(bookmark)
        XCTAssertEqual(store.load(), bookmark)
    }

    func test_returns_nil_when_no_bookmark_stored() {
        let store = BookmarkStore(defaults: defaults, key: key)
        XCTAssertNil(store.load())
    }

    func test_clear_removes_stored_bookmark() {
        let store = BookmarkStore(defaults: defaults, key: key)
        store.save(Data([0xFF]))
        store.clear()
        XCTAssertNil(store.load())
    }
}
