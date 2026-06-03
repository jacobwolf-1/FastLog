import Foundation

// Models mirror the FastLog backend JSON contract.
// Source of truth: docs/api.md, src/domain.ts, verified against live memory-mode responses.
// All macro/micro fields are optional because the backend omits null nutrition keys.

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack, unspecified
    var id: String { rawValue }
    var label: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .unspecified: return "Unspecified"
        }
    }
}

enum WeightSource: String, Codable {
    case appleHealth = "apple_health"
    case manual
    case `import`
}

struct FoodLog: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let loggedAt: String
    let mealType: MealType
    let label: String?
    let calories: Double
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
    let fiberG: Double?
    let sodiumMg: Double?
    let sugarG: Double?
    let potassiumMg: Double?
    let savedMealId: String?
    let servingMultiplier: Double
    let source: String
    let rawInput: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
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
        case savedMealId = "saved_meal_id"
        case servingMultiplier = "serving_multiplier"
        case source
        case rawInput = "raw_input"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct DailyTargets: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let calories: Double
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
    let fiberG: Double?
    let sodiumMg: Double?
    let sugarG: Double?
    let potassiumMg: Double?
    let effectiveDate: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sodiumMg = "sodium_mg"
        case sugarG = "sugar_g"
        case potassiumMg = "potassium_mg"
        case effectiveDate = "effective_date"
        case createdAt = "created_at"
    }
}

// totals and remaining always contain all 8 keys (server zero-fills).
struct NutritionTotals: Codable, Hashable {
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let sodiumMg: Double
    let sugarG: Double
    let potassiumMg: Double

    enum CodingKeys: String, CodingKey {
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

struct Dashboard: Codable {
    let date: String
    let targets: DailyTargets?
    let totals: NutritionTotals
    let remaining: NutritionTotals
    let logs: [FoodLog]
}

struct SavedMeal: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let name: String
    let normalizedName: String
    let defaultMealType: MealType
    let calories: Double
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
    let fiberG: Double?
    let sodiumMg: Double?
    let sugarG: Double?
    let potassiumMg: Double?
    let aliases: [String]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case normalizedName = "normalized_name"
        case defaultMealType = "default_meal_type"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sodiumMg = "sodium_mg"
        case sugarG = "sugar_g"
        case potassiumMg = "potassium_mg"
        case aliases
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SavedMealResolution: Codable {
    let matchStatus: String
    let matchType: String?
    let confidence: Double?
    let savedMeal: SavedMeal?
    let message: String?

    var isFound: Bool { matchStatus == "found" }

    enum CodingKeys: String, CodingKey {
        case matchStatus = "match_status"
        case matchType = "match_type"
        case confidence
        case savedMeal = "saved_meal"
        case message
    }
}

struct WeightEntry: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let measuredAt: String
    let weightLb: Double
    let source: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case measuredAt = "measured_at"
        case weightLb = "weight_lb"
        case source
        case createdAt = "created_at"
    }
}

struct WeightTrend: Codable {
    let range: String
    let points: [WeightEntry]
    let averageWeightLb: Double?
    let changeLb: Double?

    enum CodingKeys: String, CodingKey {
        case range
        case points
        case averageWeightLb = "average_weight_lb"
        case changeLb = "change_lb"
    }
}

// Wrappers for list endpoints.
struct FoodLogList: Codable { let foodLogs: [FoodLog]
    enum CodingKeys: String, CodingKey { case foodLogs = "food_logs" } }
struct SavedMealList: Codable { let savedMeals: [SavedMeal]
    enum CodingKeys: String, CodingKey { case savedMeals = "saved_meals" } }
