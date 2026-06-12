import Foundation
import Observation

// Persisted app settings. The primary auth path is Supabase (AuthManager);
// developer mode keeps the original manual-bearer-token flow for local
// memory-mode backend testing.
@MainActor
@Observable
final class AppSettings {
    var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Keys.baseURL) }
    }

    /// When true, RootView skips Supabase auth and APIClient sends `devToken`.
    var devModeEnabled: Bool {
        didSet { defaults.set(devModeEnabled, forKey: Keys.devMode) }
    }

    var devToken: String {
        didSet { defaults.set(devToken, forKey: Keys.token) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.baseURL = defaults.string(forKey: Keys.baseURL) ?? AppConfig.defaultAPIBaseURL
        self.devModeEnabled = defaults.bool(forKey: Keys.devMode)
        self.devToken = defaults.string(forKey: Keys.token) ?? Self.defaultDevToken
    }

    static let defaultLocalBaseURL = "http://localhost:8787"
    static let defaultDevToken = "dev:user-a:user-a@example.test"

    private enum Keys {
        static let baseURL = "fastlog.baseURL"
        static let devMode = "fastlog.devMode"
        static let token = "fastlog.token"
    }
}
