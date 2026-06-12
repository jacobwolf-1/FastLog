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

    @State private var hasExisting = false
    @State private var loading = false
    @State private var saving = false
    @State private var errorText: String?
    @State private var showSaved = false

    private var canSave: Bool { (calories.optionalDouble ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                if loading {
                    Section { ProgressView().frame(maxWidth: .infinity) }
                } else if !hasExisting {
                    Section {
                        Label {
                            Text("No targets yet — set a calorie target to turn on dashboard progress. Macros and micros are optional.")
                        } icon: {
                            Image(systemName: "target")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                Section {
                    NumberField(title: "Calories", unit: "cal", text: $calories)
                    NumberField(title: "Protein", unit: "g", text: $protein)
                    NumberField(title: "Carbs", unit: "g", text: $carbs)
                    NumberField(title: "Fat", unit: "g", text: $fat)
                } header: {
                    Text("Daily targets")
                } footer: {
                    Text("Calories are required; everything else is optional.")
                }

                Section("Micronutrients (optional)") {
                    NumberField(title: "Fiber", unit: "g", text: $fiber)
                    NumberField(title: "Sodium", unit: "mg", text: $sodium)
                    NumberField(title: "Sugar", unit: "g", text: $sugar)
                    NumberField(title: "Potassium", unit: "mg", text: $potassium)
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.subheadline) }
                }

                Section {
                    EmptyView()
                } footer: {
                    Text("Saved targets take effect today and apply to every day going forward. Past days keep the targets that were active at the time.")
                }
            }
            .navigationTitle("Targets")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(!canSave || saving)
                }
            }
            .overlay(alignment: .bottom) {
                if showSaved {
                    Label("Targets saved", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                        .foregroundStyle(.green)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: showSaved)
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        errorText = nil
        do {
            if let t = try await client.currentTargets() {
                hasExisting = true
                calories = t.calories.trimmedString
                protein = t.proteinG?.trimmedString ?? ""
                carbs = t.carbsG?.trimmedString ?? ""
                fat = t.fatG?.trimmedString ?? ""
                fiber = t.fiberG?.trimmedString ?? ""
                sodium = t.sodiumMg?.trimmedString ?? ""
                sugar = t.sugarG?.trimmedString ?? ""
                potassium = t.potassiumMg?.trimmedString ?? ""
            } else {
                hasExisting = false
            }
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }

    private func save() async {
        saving = true
        errorText = nil
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
            hasExisting = true
            showSaved = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                showSaved = false
            }
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        saving = false
    }
}
