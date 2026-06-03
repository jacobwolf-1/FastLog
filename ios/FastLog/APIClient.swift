import Foundation
import Observation

// Request payloads. Optional fields are omitted from JSON when nil
// (Swift synthesizes encodeIfPresent for optionals), matching the backend's
// "missing means leave unset" semantics.

struct CreateFoodLogPayload: Encodable {
    var loggedAt: String?
    var mealType: String?
    var label: String?
    var calories: Double
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fiberG: Double?
    var sodiumMg: Double?
    var sugarG: Double?
    var potassiumMg: Double?
    var rawInput: String?

    enum CodingKeys: String, CodingKey {
        case loggedAt = "logged_at"
        case mealType = "meal_type"
        case label
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sodiumMg = "sodium_mg"
        case sugarG = "sugar_g"
        case potassiumMg = "potassium_mg"
        case rawInput = "raw_input"
    }
}

// PATCH /v1/food-logs/{id}. Unlike create, the edit screen sends the fields it
// manages *explicitly* — a nil optional encodes as JSON null so the backend
// clears it (present+null = clear). Fields not listed here (logged_at, raw_input)
// stay omitted and therefore unchanged.
struct UpdateFoodLogPayload: Encodable {
    var mealType: String
    var label: String?
    var calories: Double
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fiberG: Double?
    var sodiumMg: Double?
    var sugarG: Double?
    var potassiumMg: Double?

    enum CodingKeys: String, CodingKey {
        case mealType = "meal_type"
        case label
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sodiumMg = "sodium_mg"
        case sugarG = "sugar_g"
        case potassiumMg = "potassium_mg"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mealType, forKey: .mealType)
        try c.encode(calories, forKey: .calories)
        try c.encodeNullable(label, forKey: .label)
        try c.encodeNullable(proteinG, forKey: .proteinG)
        try c.encodeNullable(carbsG, forKey: .carbsG)
        try c.encodeNullable(fatG, forKey: .fatG)
        try c.encodeNullable(fiberG, forKey: .fiberG)
        try c.encodeNullable(sodiumMg, forKey: .sodiumMg)
        try c.encodeNullable(sugarG, forKey: .sugarG)
        try c.encodeNullable(potassiumMg, forKey: .potassiumMg)
    }
}

struct UpdateTargetsPayload: Encodable {
    var calories: Double
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fiberG: Double?
    var sodiumMg: Double?
    var sugarG: Double?
    var potassiumMg: Double?
    var effectiveDate: String?

    enum CodingKeys: String, CodingKey {
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sodiumMg = "sodium_mg"
        case sugarG = "sugar_g"
        case potassiumMg = "potassium_mg"
        case effectiveDate = "effective_date"
    }
}

struct SavedMealPayload: Encodable {
    var name: String?
    var aliases: [String]?
    var defaultMealType: String?
    var calories: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fiberG: Double?
    var sodiumMg: Double?
    var sugarG: Double?
    var potassiumMg: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case aliases
        case defaultMealType = "default_meal_type"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sodiumMg = "sodium_mg"
        case sugarG = "sugar_g"
        case potassiumMg = "potassium_mg"
    }
}

// PATCH /v1/saved-meals/{id}. name/aliases/default_meal_type/calories are always
// present; cleared macro/micro fields encode as JSON null to clear them.
struct UpdateSavedMealPayload: Encodable {
    var name: String
    var aliases: [String]
    var defaultMealType: String
    var calories: Double
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fiberG: Double?
    var sodiumMg: Double?
    var sugarG: Double?
    var potassiumMg: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case aliases
        case defaultMealType = "default_meal_type"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sodiumMg = "sodium_mg"
        case sugarG = "sugar_g"
        case potassiumMg = "potassium_mg"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(aliases, forKey: .aliases)
        try c.encode(defaultMealType, forKey: .defaultMealType)
        try c.encode(calories, forKey: .calories)
        try c.encodeNullable(proteinG, forKey: .proteinG)
        try c.encodeNullable(carbsG, forKey: .carbsG)
        try c.encodeNullable(fatG, forKey: .fatG)
        try c.encodeNullable(fiberG, forKey: .fiberG)
        try c.encodeNullable(sodiumMg, forKey: .sodiumMg)
        try c.encodeNullable(sugarG, forKey: .sugarG)
        try c.encodeNullable(potassiumMg, forKey: .potassiumMg)
    }
}

struct LogSavedMealPayload: Encodable {
    var loggedAt: String?
    var mealType: String?
    var servingMultiplier: Double?

    enum CodingKeys: String, CodingKey {
        case loggedAt = "logged_at"
        case mealType = "meal_type"
        case servingMultiplier = "serving_multiplier"
    }
}

struct CreateWeightEntryPayload: Encodable {
    var measuredAt: String?
    var weightLb: Double
    var source: String

    enum CodingKeys: String, CodingKey {
        case measuredAt = "measured_at"
        case weightLb = "weight_lb"
        case source
    }
}

enum APIError: LocalizedError {
    case invalidBaseURL
    case server(status: Int, message: String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The backend URL in Settings is not a valid URL."
        case let .server(status, message):
            return "Server error (\(status)): \(message)"
        case let .decoding(detail):
            return "Could not read the server response. \(detail)"
        case let .transport(detail):
            return "Network error: \(detail)"
        }
    }
}

private struct ServerErrorBody: Decodable { let error: String }
private struct DeletedBody: Decodable { let deleted: Bool }

@MainActor
@Observable
final class APIClient {
    private let settings: AppSettings
    private let session: URLSession

    init(settings: AppSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    // MARK: Dashboard

    func dashboardToday() async throws -> Dashboard {
        try await request("GET", "/v1/dashboard/today")
    }

    func dashboard(date: String) async throws -> Dashboard {
        try await request("GET", "/v1/dashboard", query: [URLQueryItem(name: "date", value: date)])
    }

    // MARK: Food logs

    func listFoodLogs(date: String) async throws -> [FoodLog] {
        let wrapper: FoodLogList = try await request(
            "GET", "/v1/food-logs", query: [URLQueryItem(name: "date", value: date)])
        return wrapper.foodLogs
    }

    func createFoodLog(_ payload: CreateFoodLogPayload) async throws -> FoodLog {
        try await request("POST", "/v1/food-logs", body: payload)
    }

    func updateFoodLog(id: String, _ payload: UpdateFoodLogPayload) async throws -> FoodLog {
        try await request("PATCH", "/v1/food-logs/\(escape(id))", body: payload)
    }

    func deleteFoodLog(id: String) async throws {
        let _: DeletedBody = try await request("DELETE", "/v1/food-logs/\(escape(id))")
    }

    // MARK: Targets

    func currentTargets() async throws -> DailyTargets? {
        // The endpoint returns the targets object, or `null` when none are set.
        try await requestOptional("GET", "/v1/targets/current")
    }

    func updateTargets(_ payload: UpdateTargetsPayload) async throws -> DailyTargets {
        try await request("PATCH", "/v1/targets", body: payload)
    }

    // MARK: Saved meals

    func listSavedMeals() async throws -> [SavedMeal] {
        let wrapper: SavedMealList = try await request("GET", "/v1/saved-meals")
        return wrapper.savedMeals
    }

    func resolveSavedMeal(query: String) async throws -> SavedMealResolution {
        try await request("GET", "/v1/saved-meals/resolve", query: [URLQueryItem(name: "query", value: query)])
    }

    func createSavedMeal(_ payload: SavedMealPayload) async throws -> SavedMeal {
        try await request("POST", "/v1/saved-meals", body: payload)
    }

    func updateSavedMeal(id: String, _ payload: UpdateSavedMealPayload) async throws -> SavedMeal {
        try await request("PATCH", "/v1/saved-meals/\(escape(id))", body: payload)
    }

    func logSavedMeal(id: String, _ payload: LogSavedMealPayload) async throws -> FoodLog {
        try await request("POST", "/v1/saved-meals/\(escape(id))/log", body: payload)
    }

    func deleteSavedMeal(id: String) async throws {
        let _: DeletedBody = try await request("DELETE", "/v1/saved-meals/\(escape(id))")
    }

    // MARK: Weight

    func createWeightEntry(_ payload: CreateWeightEntryPayload) async throws -> WeightEntry {
        try await request("POST", "/v1/weight-entries", body: payload)
    }

    func weightTrend(range: String) async throws -> WeightTrend {
        try await request("GET", "/v1/weight-trend", query: [URLQueryItem(name: "range", value: range)])
    }

    // MARK: Core request plumbing

    private func request<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil
    ) async throws -> T {
        let data = try await send(method, path, query: query, body: body)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // For endpoints that may legitimately return a JSON `null`.
    private func requestOptional<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = []
    ) async throws -> T? {
        let data = try await send(method, path, query: query, body: nil)
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           text == "null" || text.isEmpty {
            return nil
        }
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func send(
        _ method: String,
        _ path: String,
        query: [URLQueryItem],
        body: Encodable?
    ) async throws -> Data {
        let base = settings.baseURL.trimmingCharacters(in: .whitespaces)
        guard var components = URLComponents(string: base) else { throw APIError.invalidBaseURL }
        var prefix = components.path
        while prefix.hasSuffix("/") { prefix.removeLast() }
        components.path = prefix + path
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidBaseURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try Self.encoder.encode(AnyEncodable(body))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Missing HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? Self.decoder.decode(ServerErrorBody.self, from: data))?.error
                ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.server(status: http.statusCode, message: message)
        }
        return data
    }

    private func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    static let decoder = JSONDecoder()
    static let encoder = JSONEncoder()
}

extension KeyedEncodingContainer {
    /// Encodes a value, or an explicit JSON null when nil (vs. encodeIfPresent,
    /// which omits the key). Used by PATCH payloads to clear backend fields.
    mutating func encodeNullable<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) }
    }
}

// Lets `send` take a heterogeneous Encodable without generics leaking everywhere.
private struct AnyEncodable: Encodable {
    private let encodeFn: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeFn = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFn(encoder) }
}
