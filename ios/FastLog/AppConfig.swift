import Foundation

// Build-time configuration. Supabase credentials load from FastLogConfig.plist,
// which is gitignored — copy FastLogConfig.example.plist and fill in your
// project's URL and anon (publishable) key. When the plist is missing or still
// holds placeholders, Supabase auth reports "not configured" and the app can
// still run in developer token mode.
enum AppConfig {
    /// Default backend base URL. Points at the local dev server; override at
    /// runtime in Developer options, or ship your own deployment's URL.
    static let defaultAPIBaseURL = "http://localhost:8787"

    static let supabaseURL: String? = value(for: "SUPABASE_URL")
    static let supabaseAnonKey: String? = value(for: "SUPABASE_ANON_KEY")

    static var isSupabaseConfigured: Bool { supabaseURL != nil && supabaseAnonKey != nil }

    private static func value(for key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "FastLogConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let raw = dict[key] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("YOUR-") else { return nil }
        return trimmed
    }
}
