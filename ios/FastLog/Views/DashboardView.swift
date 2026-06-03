import SwiftUI

struct DashboardView: View {
    @Environment(APIClient.self) private var client

    @State private var dashboard: Dashboard?
    @State private var loading = false
    @State private var errorText: String?
    @State private var showingLog = false

    var body: some View {
        NavigationStack {
            Group {
                if let dashboard {
                    content(dashboard)
                } else if loading {
                    ProgressView("Loading today…")
                } else if let errorText {
                    ErrorBanner(message: errorText) { Task { await load() } }
                        .padding()
                } else {
                    Color.clear
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingLog = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingLog) {
                ManualLogView { Task { await load() } }
            }
            .onAppear { Task { await load() } }
            .refreshable { await load() }
        }
    }

    @ViewBuilder
    private func content(_ d: Dashboard) -> some View {
        List {
            Section {
                CaloriesCard(
                    consumed: d.totals.calories,
                    remaining: d.remaining.calories,
                    target: d.targets?.calories
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Macros") {
                MacroProgressRow(title: "Protein", consumed: d.totals.proteinG, target: d.targets?.proteinG, unit: "g")
                MacroProgressRow(title: "Carbs", consumed: d.totals.carbsG, target: d.targets?.carbsG, unit: "g")
                MacroProgressRow(title: "Fat", consumed: d.totals.fatG, target: d.targets?.fatG, unit: "g")
            }

            Section("Micros") {
                MacroProgressRow(title: "Fiber", consumed: d.totals.fiberG, target: d.targets?.fiberG, unit: "g")
                MacroProgressRow(title: "Sodium", consumed: d.totals.sodiumMg, target: d.targets?.sodiumMg, unit: "mg")
                MacroProgressRow(title: "Sugar", consumed: d.totals.sugarG, target: d.targets?.sugarG, unit: "g")
                MacroProgressRow(title: "Potassium", consumed: d.totals.potassiumMg, target: d.targets?.potassiumMg, unit: "mg")
            }

            Section("Today's logs") {
                if d.logs.isEmpty {
                    Text("No food logged yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(d.logs) { log in
                        NavigationLink {
                            FoodLogEditView(log: log) { Task { await load() } }
                        } label: {
                            FoodLogRow(log: log)
                        }
                    }
                }
            }
        }
    }

    private func load() async {
        loading = true
        errorText = nil
        do {
            dashboard = try await client.dashboardToday()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}

struct FoodLogRow: View {
    let log: FoodLog

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(log.label ?? "Food log").font(.body.weight(.medium))
                Spacer()
                Text(Fmt.whole(log.calories) + " cal").monospacedDigit().foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                if log.mealType != .unspecified {
                    Text(log.mealType.label).font(.caption).foregroundStyle(.secondary)
                }
                Text("P \(Fmt.whole(log.proteinG)) · C \(Fmt.whole(log.carbsG)) · F \(Fmt.whole(log.fatG))")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Fmt.timeOfDay(fromISO: log.loggedAt)).font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}
