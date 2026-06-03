import Foundation
import Observation

// Persisted backend connection settings. Defaults point at the local memory-mode
// dev server and the user-a dev token described in CLAUDE.md.
@MainActor
@Observable
final class AppSettings {
    var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Keys.baseURL) }
    }
    var token: String {
        didSet { defaults.set(token, forKey: Keys.token) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.baseURL = defaults.string(forKey: Keys.baseURL) ?? Self.defaultBaseURL
        self.token = defaults.string(forKey: Keys.token) ?? Self.defaultToken
    }

    static let defaultBaseURL = "http://localhost:8787"
    static let defaultToken = "dev:user-a:user-a@example.test"

    private enum Keys {
        static let baseURL = "fastlog.baseURL"
        static let token = "fastlog.token"
    }
}
