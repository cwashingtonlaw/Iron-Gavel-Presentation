import Foundation

/// Pure ordering math for the exhibit sidebar. Manual `order` (set by drag) sorts first;
/// unordered exhibits follow, keeping their import order. Order values are only meaningful
/// within a grouping section, since `ExhibitGrouping` groups before sorting.
enum ExhibitReorder {
    /// Stable sort: ordered items ascending by `order`, then unordered items in import order.
    static func sorted(_ exhibits: [Exhibit]) -> [Exhibit] {
        exhibits.enumerated().sorted { a, b in
            let oa = a.element.order ?? Int.max
            let ob = b.element.order ?? Int.max
            if oa != ob { return oa < ob }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// Applies a SwiftUI `.onMove` within an already-sorted section and reassigns a dense
    /// `0..<n` order to every exhibit in the section.
    static func move(_ section: [Exhibit], fromOffsets: IndexSet, toOffset: Int) -> [Exhibit] {
        var items = section
        items.move(fromOffsets: fromOffsets, toOffset: toOffset)
        return items.enumerated().map { idx, ex in ex.withOrder(idx) }
    }
}
