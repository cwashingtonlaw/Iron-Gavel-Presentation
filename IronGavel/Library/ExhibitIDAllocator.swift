import Foundation

/// Allocates the next exhibit id for a party (D-001, S-002, …).
enum ExhibitIDAllocator {
    static func prefix(for party: Party) -> String {
        switch party {
        case .defense: return "D"
        case .state:   return "S"
        case .joint:   return "J"
        case .court:   return "C"
        }
    }

    static func nextID(existing: [Exhibit], party: Party) -> String {
        let p = prefix(for: party)
        let maxN = existing.compactMap { e -> Int? in
            guard e.id.hasPrefix("\(p)-") else { return nil }
            return Int(e.id.dropFirst(p.count + 1))
        }.max() ?? 0
        return String(format: "%@-%03d", p, maxN + 1)
    }
}
