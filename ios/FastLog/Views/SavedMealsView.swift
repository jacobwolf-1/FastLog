import SwiftUI

struct SavedMealsView: View {
    @Environment(APIClient.self) private var client

    @State private var meals: [SavedMeal] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var creating = false
    @State private var logging: SavedMeal?

    // Backend-driven resolution (GET /v1/saved-meals/resolve) — fuzzy matching
    // stays on the server, never reimplemented here.
    @State private var query = ""
    @State private var resolving = false
    @State private var resolution: SavedMealResolution?

    var body: some View {
        NavigationStack {
            Group {
                if let errorText, meals.isEmpty {
                    ScrollView {
                        ErrorBanner(message: errorText) { Task { await load() } }.padding()
                    }
                } else if meals.isEmpty && !loading {
                    ContentUnavailableView {
                        Label("No saved meals", systemImage: "fork.knife")
                    } description: {
                        Text("Save the meals you eat often, then log them in two taps — or by name from ChatGPT or Claude.")
                    } actions: {
                        Button("New saved meal") { creating = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Saved Meals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { creating = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New saved meal")
                }
            }
            .searchable(text: $query, prompt: "Resolve by name or alias")
            .onSubmit(of: .search) { Task { await resolve() } }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty { resolution = nil }
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

    private var list: some View {
        List {
            if resolving {
                Section("Match") { ProgressView() }
            } else if let resolution {
                Section("Match") { resolutionRow(resolution) }
            }

            Section {
                ForEach(meals) { meal in
                    NavigationLink {
                        SavedMealEditorView(existing: meal) { Task { await load() } }
                    } label: {
                        SavedMealRow(meal: meal) { logging = meal }
                    }
                    .swipeActions(edge: .leading) {
                        Button { logging = meal } label: {
                            Label("Log", systemImage: "plus.circle")
                        }
                        .tint(.green)
                    }
                }
            } footer: {
                Text("Swipe right or tap Log to log a meal. Search resolves by name or alias through the backend — the same matching ChatGPT and Claude use.")
            }
        }
    }

    @ViewBuilder
    private func resolutionRow(_ resolution: SavedMealResolution) -> some View {
        if resolution.isFound, let meal = resolution.savedMeal {
            SavedMealRow(meal: meal) { logging = meal }
            if let confidence = resolution.confidence {
                Text("Matched \(resolution.matchType ?? "name") · confidence \(String(format: "%.0f%%", confidence * 100))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Label(resolution.message ?? "No saved meal matched \"\(query)\".",
                  systemImage: "questionmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

    private func resolve() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        resolving = true
        do {
            resolution = try await client.resolveSavedMeal(query: trimmed)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            resolution = nil
        }
        resolving = false
    }
}

struct SavedMealRow: View {
    let meal: SavedMeal
    var onLog: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(meal.name).font(.body.weight(.medium)).lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(Fmt.whole(meal.calories)) cal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("P \(Fmt.whole(meal.proteinG)) · C \(Fmt.whole(meal.carbsG)) · F \(Fmt.whole(meal.fatG))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                if !meal.aliases.isEmpty {
                    Text(meal.aliases.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let onLog {
                Button("Log", action: onLog)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}
