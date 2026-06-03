import SwiftUI

// Manual macro entry → POST /v1/food-logs. The whole point of FastLog:
// "what numbers do you want to log?" — no food database, no search.
struct ManualLogView: View {
    @Environment(APIClient.self) private var client
    @Environment(\.dismiss) private var dismiss

    var onSaved: () -> Void

    @State private var label = ""
    @State private var mealType: MealType = .unspecified
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var sodium = ""
    @State private var sugar = ""
    @State private var potassium = ""
    @State private var showMicros = false

    @State private var saving = false
    @State private var errorText: String?

    private var caloriesValid: Bool { (calories.optionalDouble ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label (optional)", text: $label)
                    Picker("Meal type", selection: $mealType) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section("Macros") {
                    NumberField(title: "Calories", unit: "cal", text: $calories)
                    NumberField(title: "Protein", unit: "g", text: $protein)
                    NumberField(title: "Carbs", unit: "g", text: $carbs)
                    NumberField(title: "Fat", unit: "g", text: $fat)
                }

                Section {
                    DisclosureGroup("Micronutrients (optional)", isExpanded: $showMicros) {
                        NumberField(title: "Fiber", unit: "g", text: $fiber)
                        NumberField(title: "Sodium", unit: "mg", text: $sodium)
                        NumberField(title: "Sugar", unit: "g", text: $sugar)
                        NumberField(title: "Potassium", unit: "mg", text: $potassium)
                    }
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.subheadline) }
                }
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!caloriesValid || saving)
                }
            }
        }
    }

    private func save() async {
        saving = true
        errorText = nil
        let payload = CreateFoodLogPayload(
            mealType: mealType == .unspecified ? nil : mealType.rawValue,
            label: label.isEmpty ? nil : label,
            calories: calories.optionalDouble ?? 0,
            proteinG: protein.optionalDouble,
            carbsG: carbs.optionalDouble,
            fatG: fat.optionalDouble,
            fiberG: fiber.optionalDouble,
            sodiumMg: sodium.optionalDouble,
            sugarG: sugar.optionalDouble,
            potassiumMg: potassium.optionalDouble
        )
        do {
            _ = try await client.createFoodLog(payload)
            onSaved()
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        saving = false
    }
}
