import XCTest
@testable import IronGavel

@MainActor
final class AppStateSharedTests: XCTestCase {
    /// The jury scene and the presenter must observe the SAME instance, or the external
    /// display won't mirror the presenter. Guards against `shared` regressing to a computed
    /// property that hands out a fresh AppState each access.
    func test_shared_is_a_single_stable_instance() {
        XCTAssertTrue(AppState.shared === AppState.shared)
    }

    func test_shared_state_changes_are_visible_through_the_same_reference() {
        let a = AppState.shared
        let b = AppState.shared
        a.externalConnected.toggle()
        XCTAssertEqual(a.externalConnected, b.externalConnected)
        a.externalConnected.toggle()   // restore, since it's a process-wide singleton
    }
}
