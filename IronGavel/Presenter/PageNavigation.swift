import Foundation

/// Pure page-index math for the document viewer, so navigation stays in bounds
/// regardless of how a jump is requested (button, field, or jump-to-page menu).
enum PageNavigation {
    /// Clamps `page` to `[0, count - 1]`. Returns 0 when `count` is unknown (<= 0).
    static func clampPage(_ page: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(0, page), count - 1)
    }
}
