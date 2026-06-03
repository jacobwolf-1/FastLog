import SwiftUI

// Create or edit a saved meal. Aliases are entered as comma-separated text and
// sent as a replacement list (the backend replaces the alias set when `aliases`
// is present). Fuzzy resolution stays on the backend — never duplicated here.
struct SavedMealEditorView: View {
    @Environment(APIClient.self) private var client
    @Environment(\.dismiss) private var dismiss

    let existing: SavedMeal?
    var onChanged: () -> Void

    @State private var name: String
    @State private var aliasesText: String
    @State private var defaultMealType: MealType
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String
    @State private var sodium: String
    @State private var sugar: String
    @State private var potassium: String

    @State private var saving = false
    @State private var deleting = false
    @State private var errorText: String?
    @State private var confirmDelete = false

    init(existing: SavedMeal?, onChanged: @escaping () -> Void) {
        self.existing = existing
        self.onChanged = onChanged
        _name = State(initialValue: existing?.name ?? "")
        _aliasesText = State(initialValue: existing?.aliases.joined(separator: ", ") ?? "")
        _defaultMealType = State(initialValue: existing?.defaultMealType ?? .unspecified)
        _calories = State(initialValue: existing?.calories.trimmedString ?? "")
        _protein = State(initialValue: existing?.proteinG?.trimmedString ?? "")
        _carbs = State(initialValue: existing?.carbsG?.trimmedString ?? "")
        _fat = State(initialValue: existing?.fatG?.trimmedString ?? "")
        _fiber = State(initialValue: existing?.fiberG?.trimmedString ?? "")
        _sodium = State(initialValue: existing?.sodiumMg?.trimmedString ?? "")
        _sugar = State(initialValue: existing?.sugarG?.trimmedString ?? "")
        _potassium = State(initialValue: existing?.potassiumMg?.trimmedString ?? "")
    }

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && (calories.optionalDouble ?? 0) > 0 }

    private var aliasList: [String] {
        aliasesText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                Picker("Default meal type", selection: $defaultMealType) {
                    ForEach(MealType.allCases) { Text($0.label).tag($0) }
                }
            }
            Section {
                TextField("Aliases (comma-separated)", text: $aliasesText, axis: .vertical)
            } header: {
                Text("Aliases")
            } footer: {
                Text("Used by backend resolution. Editing replaces the full alias set.")
            }
            Section("Macros") {
                NumberField(title: "Calories", unit: "cal", text: $calories)
                NumberField(title: "Protein", unit: "g", text: $protein)
                NumberField(title: "Carbs", unit: "g", text: $carbs)
                NumberField(title: "Fat", unit: "g", text: $fat)
            }
            Section("Micronutrients (optional)") {
                NumberField(title: "Fiber", unit: "g", text: $fiber)
                NumberField(title: "Sodium", unit: "mg", text: $sodium)
                NumberField(title: "Sugar", unit: "g", text: $sugar)
                NumberField(title: "Potassium", unit: "mg", text: $potassium)
            }
            if isEditing {
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        if deleting { ProgressView() } else { Text("Delete saved meal") }
                    }
                }
            }
            if let errorText {
                Section { Text(errorText).foregroundStyle(.red).font(.subheadline) }
            }
        }
        .navigationTitle(isEditing ? "Edit Meal" : "New Meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }.disabled(!canSave || saving)
            }
        }
        .confirmationDialog("Delete this saved meal?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await remove() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func save() async {
        saving = true
        errorText = nil
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        do {
            if let existing {
                // Update: cleared macro/micro fields are sent as explicit null to clear them.
                let payload = UpdateSavedMealPayload(
                    name: trimmedName,
                    aliases: aliasList,
                    defaultMealType: defaultMealType.rawValue,
                    calories: calories.optionalDouble ?? 0,
                    proteinG: protein.optionalDouble,
                    carbsG: carbs.optionalDouble,
                    fatG: fat.optionalDouble,
                    fiberG: fiber.optionalDouble,
                    sodiumMg: sodium.optionalDouble,
                    sugarG: sugar.optionalDouble,
                    potassiumMg: potassium.optionalDouble
                )
                _ = try await client.updateSavedMeal(id: existing.id, payload)
            } else {
                // Create: omit unset optionals (no clearing semantics needed).
                let payload = SavedMealPayload(
                    name: trimmedName,
                    aliases: aliasList,
                    defaultMealType: defaultMealType.rawValue,
                    calories: calories.optionalDouble,
                    proteinG: protein.optionalDouble,
                    carbsG: carbs.optionalDouble,
                    fatG: fat.optionalDouble,
                    fiberG: fiber.optionalDouble,
                    sodiumMg: sodium.optionalDouble,
                    sugarG: sugar.optionalDouble,
                    potassiumMg: potassium.optionalDouble
                )
                _ = try await client.createSavedMeal(payload)
            }
            onChanged()
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        saving = false
    }

    private func remove() async {
        guard let existing else { return }
        deleting = true
        errorText = nil
        do {
            try await client.deleteSavedMeal(id: existing.id)
            onChanged()
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        deleting = false
    }
}

// Log a saved meal with an optional serving multiplier and meal-type override.
struct LogSavedMealView: View {
    @Environment(APIClient.self) private var client
    @Environment(\.dismiss) private var dismiss

    let meal: SavedMeal
    @State private var multiplier = "1"
    @State private var mealType: MealType
    @State private var saving = false
    @State private var errorText: String?

    init(meal: SavedMeal) {
        self.meal = meal
        _mealType = State(initialValue: meal.defaultMealType)
    }

    private var factor: Double { multiplier.optionalDouble ?? 1 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Scaled totals") {
                    LabeledContent("Calories", value: Fmt.whole(meal.calories * factor))
                    LabeledContent("Protein", value: Fmt.grams((meal.proteinG ?? 0) * factor))
                    LabeledContent("Carbs", value: Fmt.grams((meal.carbsG ?? 0) * factor))
                    LabeledContent("Fat", value: Fmt.grams((meal.fatG ?? 0) * factor))
                }
                Section {
                    NumberField(title: "Servings", unit: "×", text: $multiplier)
                    Picker("Meal type", selection: $mealType) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.subheadline) }
                }
            }
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { Task { await log() } }.disabled(factor <= 0 || saving)
                }
            }
        }
    }

    private func log() async {
        saving = true
        errorText = nil
        let payload = LogSavedMealPayload(
            mealType: mealType.rawValue,
            servingMultiplier: factor
        )
        do {
            _ = try await client.logSavedMeal(id: meal.id, payload)
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        saving = false
    }
}
