import Foundation

enum SidebarGrouping: String, CaseIterable, Hashable {
    case party = "Party"
    case folder = "Folder"
}

/// Pure grouping for the exhibit sidebar. Produces ordered, non-empty sections.
enum ExhibitGrouping {
    static let unfiledTitle = "Unfiled"

    struct Section: Equatable { let title: String; let exhibits: [Exhibit] }

    static func sections(for exhibits: [Exhibit], mode: SidebarGrouping) -> [Section] {
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
        }
    }
}
