import SwiftUI

struct SavedMealsView: View {
    @Environment(APIClient.self) private var client

    @State private var meals: [SavedMeal] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var creating = false
    @State private var logging: SavedMeal?

    var body: some View {
        NavigationStack {
            Group {
                if let errorText, meals.isEmpty {
                    ErrorBanner(message: errorText) { Task { await load() } }.padding()
                } else {
                    List {
                        if meals.isEmpty && !loading {
                            Text("No saved meals yet. Tap + to create one.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(meals) { meal in
                            NavigationLink {
                                SavedMealEditorView(existing: meal) { Task { await load() } }
                            } label: {
                                SavedMealRow(meal: meal)
                            }
                            .swipeActions(edge: .leading) {
                                Button { logging = meal } label: { Label("Log", systemImage: "plus.circle") }
                                    .tint(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved Meals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { creating = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $creating) {
                NavigationStack {
                    SavedMealEditorView(existing: nil) { Task { await load() } }
                }
            }
            .sheet(item: $logging) { meal in
                LogSavedMealView(meal: meal)
            }
            .task { if meals.isEmpty { await load() } }
            .refreshable { await load() }
        }
    }

    private func load() async {
        loading = true
        errorText = nil
        do {
            meals = try await client.listSavedMeals()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}

struct SavedMealRow: View {
    let meal: SavedMeal
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(meal.name).font(.body.weight(.medium))
                Spacer()
                Text(Fmt.whole(meal.calories) + " cal").foregroundStyle(.secondary).monospacedDigit()
            }
            Text("P \(Fmt.whole(meal.proteinG)) · C \(Fmt.whole(meal.carbsG)) · F \(Fmt.whole(meal.fatG))")
                .font(.caption).foregroundStyle(.secondary)
            if !meal.aliases.isEmpty {
                Text(meal.aliases.joined(separator: ", "))
                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
    }
}
