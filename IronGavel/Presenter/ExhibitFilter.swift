import Foundation

/// Pure search/filter for the exhibit sidebar. Matches a free-text query against an
/// exhibit's id, description, witness, and Bates number (case-insensitive substring).
enum ExhibitFilter {
    static func matches(_ exhibit: Exhibit, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        let fields = [exhibit.id, exhibit.description, exhibit.witness ?? "", exhibit.bates ?? ""]
        return fields.contains { $0.lowercased().contains(q) }
    }
}
