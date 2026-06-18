import Foundation

/// One stop in a presentation binder: an exhibit shown at a specific page. The attorney
/// builds an ordered run-of-show, then steps through it during argument.
struct BinderStep: Codable, Hashable, Identifiable {
    let exhibitId: String
    let page: Int
    /// Stable identity for SwiftUI lists, independent of position.
    let id: String

    init(exhibitId: String, page: Int, id: String = UUID().uuidString) {
        self.exhibitId = exhibitId
        self.page = page
        self.id = id
    }

    enum CodingKeys: String, CodingKey {
        case exhibitId = "exhibit_id"
        case page, id
    }
}

/// Atomic read/write of the presentation binder (`<CASE_ROOT>/Trial/binder.json`).
/// Purely additive — never touches the generated exhibits.json or the publish gate.
struct BinderStore {
    static let fileName = "binder.json"

    func load(from caseFolder: URL) -> [BinderStep] {
        let url = caseFolder.appendingPathComponent("Trial/\(Self.fileName)")
        guard let data = try? Data(contentsOf: url),
              let steps = try? JSONDecoder().decode([BinderStep].self, from: data) else { return [] }
        return steps
    }

    func save(_ steps: [BinderStep], to caseFolder: URL) throws {
        let dir = caseFolder.appendingPathComponent("Trial")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(Self.fileName)
        let data = try JSONEncoder().encode(steps)
        try data.write(to: url, options: .atomic)
    }
}
