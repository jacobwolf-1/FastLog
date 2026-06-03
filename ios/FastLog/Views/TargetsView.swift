import SwiftUI

// Read current targets (GET /v1/targets/current) and upsert (PATCH /v1/targets).
struct TargetsView: View {
    @Environment(APIClient.self) private var client

    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var sodium = ""
    @State private var sugar = ""
    @State private var potassium = ""

    @State private var loading = false
    @State private var saving = false
    @State private var errorText: String?
    @State private var savedNote: String?

    private var canSave: Bool { (calories.optionalDouble ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                if loading {
                    Section { ProgressView() }
                }
                Section("Daily targets") {
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
                if let savedNote {
                    Section { Label(savedNote, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.subheadline) }
                }
            }
            .navigationTitle("Targets")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(!canSave || saving)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        errorText = nil
        do {
            if let t = try await client.currentTargets() {
                calories = t.calories.trimmedString
                protein = t.proteinG?.trimmedString ?? ""
                carbs = t.carbsG?.trimmedString ?? ""
                fat = t.fatG?.trimmedString ?? ""
                fiber = t.fiberG?.trimmedString ?? ""
                sodium = t.sodiumMg?.trimmedString ?? ""
                sugar = t.sugarG?.trimmedString ?? ""
                potassium = t.potassiumMg?.trimmedString ?? ""
            }
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }

    private func save() async {
        saving = true
        errorText = nil
        savedNote = nil
        let payload = UpdateTargetsPayload(
            calories: calories.optionalDouble ?? 0,
            proteinG: protein.optionalDouble,
            carbsG: carbs.optionalDouble,
            fatG: fat.optionalDouble,
            fiberG: fiber.optionalDouble,
            sodiumMg: sodium.optionalDouble,
            sugarG: sugar.optionalDouble,
            potassiumMg: potassium.optionalDouble,
            effectiveDate: Fmt.isoDay()
        )
        do {
            _ = try await client.updateTargets(payload)
            savedNote = "Targets saved."
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        saving = false
    }
}
