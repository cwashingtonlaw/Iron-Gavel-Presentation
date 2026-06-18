import Foundation

enum SidebarGrouping: String, CaseIterable, Hashable {
    case party = "Party"
    case folder = "Folder"
    case witness = "Witness"
}

/// Pure grouping for the exhibit sidebar. Produces ordered, non-empty sections.
enum ExhibitGrouping {
    static let unfiledTitle = "Unfiled"
    static let noWitnessTitle = "No Witness"

    struct Section: Equatable { let title: String; let exhibits: [Exhibit] }

    static func sections(for exhibits: [Exhibit], mode: SidebarGrouping,
                         sort: ExhibitSort = .custom) -> [Section] {
        // Group first, then order each section by the chosen sort (default = manual order).
        rawSections(for: exhibits, mode: mode).map {
            Section(title: $0.title, exhibits: ExhibitSorter.sorted($0.exhibits, by: sort))
        }
    }

    private static func rawSections(for exhibits: [Exhibit], mode: SidebarGrouping) -> [Section] {
        switch mode {
        case .party:
            return Party.allCases.compactMap { party in
                let items = exhibits.filter { $0.party == party }
                return items.isEmpty ? nil : Section(title: party.rawValue, exhibits: items)
            }
        case .folder:
            let named = Dictionary(grouping: exhibits.filter { $0.folder != nil },
                                   by: { $0.folder! })
            var sections = named.keys.sorted().map { key in
                Section(title: key, exhibits: named[key]!)
            }
            let unfiled = exhibits.filter { $0.folder == nil }
            if !unfiled.isEmpty { sections.append(Section(title: unfiledTitle, exhibits: unfiled)) }
            return sections
        case .witness:
            let named = Dictionary(grouping: exhibits.filter { $0.witness != nil },
                                   by: { $0.witness! })
            var sections = named.keys.sorted().map { key in
                Section(title: key, exhibits: named[key]!)
            }
            let noWitness = exhibits.filter { $0.witness == nil }
            if !noWitness.isEmpty { sections.append(Section(title: noWitnessTitle, exhibits: noWitness)) }
            return sections
        }
    }
}
