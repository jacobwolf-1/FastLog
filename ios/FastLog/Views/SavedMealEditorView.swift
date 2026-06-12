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
// Scaled macros preview live before logging; scaling itself happens on the
// backend via serving_multiplier.
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
    private let quickFactors: [Double] = [0.5, 1, 1.5, 2]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Fmt.whole(meal.calories * factor))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("cal").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
                    HStack {
                        scaledMetric("Protein", meal.proteinG, tint: FLColor.protein)
                        scaledMetric("Carbs", meal.carbsG, tint: FLColor.carbs)
                        scaledMetric("Fat", meal.fatG, tint: FLColor.fat)
                    }
                }

                Section("Servings") {
                    HStack(spacing: 8) {
                        ForEach(quickFactors, id: \.self) { f in
                            let selected = factor == f
                            Button {
                                multiplier = f.trimmedString
                            } label: {
                                Text("\(f.trimmedString)×")
                                    .font(.subheadline.weight(selected ? .semibold : .regular))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(selected
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(.tertiarySystemFill)))
                                    .foregroundStyle(selected ? Color.accentColor : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    NumberField(title: "Custom", unit: "×", text: $multiplier)
                }

                Section("Meal type") {
                    MealTypeChips(selection: $mealType)
                        .listRowSeparator(.hidden)
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
                    Button {
                        Task { await log() }
                    } label: {
                        if saving { ProgressView() } else { Text("Log").fontWeight(.semibold) }
                    }
                    .disabled(factor <= 0 || saving)
                }
            }
        }
    }

    private func scaledMetric(_ title: String, _ base: Double?, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(base.map { Fmt.whole($0 * factor) } ?? "—")
                .font(.body.weight(.semibold))
                .monospacedDigit()
            Text("\(title) g")
                .font(.caption2)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
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
