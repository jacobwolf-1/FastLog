import Foundation

enum Fmt {
    static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(fromISO value: String) -> Date? {
        isoFractional.date(from: value) ?? iso.date(from: value)
    }

    /// "YYYY-MM-DD" for the user's current local day, matching the backend date contract.
    static func isoDay(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func timeOfDay(fromISO value: String) -> String {
        guard let d = date(fromISO: value) else { return "" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: d)
    }

    static func shortDate(fromISO value: String) -> String {
        guard let d = date(fromISO: value) else { return value }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    static func whole(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(Int(value.rounded()))
    }

    static func grams(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded())) g"
    }

    static func mg(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded())) mg"
    }

    static func weight(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f lb", value)
    }
}
