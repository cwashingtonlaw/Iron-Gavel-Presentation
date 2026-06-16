import Foundation

/// Persists the currently-published jury state (exhibit id + page + blanked) so a
/// crash or relaunch mid-trial can restore exactly what the jury was seeing.
/// UserDefaults-backed, mirroring BookmarkStore.
struct PublishStateStore {
    static let defaultKey = "iron-gavel.lastPublishState"

    struct State: Codable, Equatable {
        let exhibitId: String
        let page: Int
        let blanked: Bool
    }

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = PublishStateStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func save(_ state: State) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        }
    }

    func load() -> State? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
