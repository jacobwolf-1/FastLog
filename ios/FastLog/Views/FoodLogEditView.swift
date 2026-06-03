import SwiftUI

// Edit (PATCH) and delete (DELETE) one existing food log.
struct FoodLogEditView: View {
    @Environment(APIClient.self) private var client
    @Environment(\.dismiss) private var dismiss

    let log: FoodLog
    var onChanged: () -> Void

    @State private var label: String
    @State private var mealType: MealType
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

    init(log: FoodLog, onChanged: @escaping () -> Void) {
        self.log = log
        self.onChanged = onChanged
        _label = State(initialValue: log.label ?? "")
        _mealType = State(initialValue: log.mealType)
        _calories = State(initialValue: log.calories.trimmedString)
        _protein = State(initialValue: log.proteinG?.trimmedString ?? "")
        _carbs = State(initialValue: log.carbsG?.trimmedString ?? "")
        _fat = State(initialValue: log.fatG?.trimmedString ?? "")
        _fiber = State(initialValue: log.fiberG?.trimmedString ?? "")
        _sodium = State(initialValue: log.sodiumMg?.trimmedString ?? "")
        _sugar = State(initialValue: log.sugarG?.trimmedString ?? "")
        _potassium = State(initialValue: log.potassiumMg?.trimmedString ?? "")
    }

    private var caloriesValid: Bool { (calories.optionalDouble ?? 0) > 0 }

    var body: some View {
        Form {
            Section {
                TextField("Label", text: $label)
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
            Section("Micronutrients") {
                NumberField(title: "Fiber", unit: "g", text: $fiber)
                NumberField(title: "Sodium", unit: "mg", text: $sodium)
                NumberField(title: "Sugar", unit: "g", text: $sugar)
                NumberField(title: "Potassium", unit: "mg", text: $potassium)
            }
            Section {
                Button(role: .destructive) { confirmDelete = true } label: {
                    if deleting { ProgressView() } else { Text("Delete log") }
                }
            }
            if let errorText {
                Section { Text(errorText).foregroundStyle(.red).font(.subheadline) }
            }
        }
        .navigationTitle("Edit Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(!caloriesValid || saving)
            }
        }
        .confirmationDialog("Delete this food log?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await remove() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func save() async {
        saving = true
        errorText = nil
        // Send the full editable set; cleared label/micro fields explicitly become null.
        let payload = UpdateFoodLogPayload(
            mealType: mealType.rawValue,
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
            _ = try await client.updateFoodLog(id: log.id, payload)
            onChanged()
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        saving = false
    }

    private func remove() async {
        deleting = true
        errorText = nil
        do {
            try await client.deleteFoodLog(id: log.id)
            onChanged()
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        deleting = false
    }
}
