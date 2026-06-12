import SwiftUI

// Manual macro entry → POST /v1/food-logs. The whole point of FastLog:
// "what numbers do you want to log?" — no food database, no search.
// Optimized for speed: calories focused on open, chips not pickers,
// micros tucked away.
struct ManualLogView: View {
    @Environment(APIClient.self) private var client
    @Environment(\.dismiss) private var dismiss

    var onSaved: () -> Void

    private enum Field: Hashable {
        case calories, label, protein, carbs, fat, fiber, sodium, sugar, potassium
    }

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
    @FocusState private var focus: Field?

    private var caloriesValid: Bool { (calories.optionalDouble ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    caloriesHero
                    MealTypeChips(selection: $mealType)

                    TextField("Label (optional) — e.g. Chicken & rice", text: $label)
                        .focused($focus, equals: .label)
                        .flCard()

                    macroFields

                    DisclosureGroup(isExpanded: $showMicros) {
                        VStack(spacing: 2) {
                            NumberField(title: "Fiber", unit: "g", text: $fiber)
                                .focused($focus, equals: .fiber)
                            NumberField(title: "Sodium", unit: "mg", text: $sodium)
                                .focused($focus, equals: .sodium)
                            NumberField(title: "Sugar", unit: "g", text: $sugar)
                                .focused($focus, equals: .sugar)
                            NumberField(title: "Potassium", unit: "mg", text: $potassium)
                                .focused($focus, equals: .potassium)
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("Micronutrients")
                            .font(.subheadline.weight(.medium))
                    }
                    .flCard()

                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if saving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Log it").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!caloriesValid || saving)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .onAppear { focus = .calories }
        }
    }

    private var caloriesHero: some View {
        VStack(spacing: 2) {
            TextField("0", text: $calories)
                .keyboardType(.decimalPad)
                .focused($focus, equals: .calories)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
            Text("calories")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .flCard()
    }

    private var macroFields: some View {
        HStack(spacing: 10) {
            macroField("Protein", tint: FLColor.protein, text: $protein, field: .protein)
            macroField("Carbs", tint: FLColor.carbs, text: $carbs, field: .carbs)
            macroField("Fat", tint: FLColor.fat, text: $fat, field: .fat)
        }
    }

    private func macroField(_ title: String, tint: Color, text: Binding<String>, field: Field) -> some View {
        VStack(spacing: 4) {
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .focused($focus, equals: field)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.center)
            Text("\(title) g")
                .font(.caption)
                .foregroundStyle(tint)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func save() async {
        saving = true
        errorText = nil
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        let payload = CreateFoodLogPayload(
            mealType: mealType == .unspecified ? nil : mealType.rawValue,
            label: trimmedLabel.isEmpty ? nil : trimmedLabel,
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
