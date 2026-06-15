import Foundation

struct BookmarkStore {
    static let defaultKey = "iron-gavel.lastCaseBookmark"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = BookmarkStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func save(_ data: Data) {
        defaults.set(data, forKey: key)
    }

    func load() -> Data? {
        defaults.data(forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
