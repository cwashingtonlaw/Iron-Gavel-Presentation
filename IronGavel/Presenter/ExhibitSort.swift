import Foundation

/// How exhibits are ordered within a sidebar section (TrialPad's Name / Custom / Admitted /
/// Exhibit # selector). "Custom" is the manual drag order; the rest derive from the data.
enum ExhibitSort: String, CaseIterable, Hashable {
    case custom = "Custom"
    case name = "Name"
    case admitted = "Admitted"
    case exhibitNumber = "Exhibit #"
}

enum ExhibitSorter {
    static func sorted(_ exhibits: [Exhibit], by sort: ExhibitSort) -> [Exhibit] {
        switch sort {
        case .custom:
            return ExhibitReorder.sorted(exhibits)
        case .name:
            return stableSorted(exhibits) {
                $0.description.localizedStandardCompare($1.description) == .orderedAscending
            }
        case .admitted:
            return stableSorted(exhibits) { rank($0) < rank($1) }
        case .exhibitNumber:
            return stableSorted(exhibits) { a, b in
                switch (a.displayNumber, b.displayNumber) {
                case let (x?, y?): return x.localizedStandardCompare(y) == .orderedAscending
                case (_?, nil):    return true     // numbered before unnumbered
                case (nil, _?):    return false
                case (nil, nil):   return false     // keep stable (tiebreak by import order)
                }
            }
        }
    }

    private static func rank(_ e: Exhibit) -> Int { e.status == .admitted ? 0 : 1 }

    /// Stable sort: ties keep their original (import) order.
    private static func stableSorted(_ items: [Exhibit],
                                     _ areInIncreasingOrder: (Exhibit, Exhibit) -> Bool) -> [Exhibit] {
        items.enumerated().sorted { a, b in
            if areInIncreasingOrder(a.element, b.element) { return true }
            if areInIncreasingOrder(b.element, a.element) { return false }
            return a.offset < b.offset
        }.map(\.element)
    }
}
