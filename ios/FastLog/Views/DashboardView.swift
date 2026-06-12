import SwiftUI

// Flagship screen: today's calories, macro gauges, micro bars, and the day's
// logs — all straight from GET /v1/dashboard/today.
struct DashboardView: View {
    @Environment(APIClient.self) private var client
    @Environment(AppRouter.self) private var router

    @State private var dashboard: Dashboard?
    @State private var loading = false
    @State private var errorText: String?
    @State private var showingLog = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let dashboard {
                        content(dashboard)
                    } else if loading {
                        ProgressView("Loading today…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorText {
                        ScrollView {
                            ErrorBanner(message: errorText) { Task { await load() } }
                                .padding()
                        }
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if dashboard != nil {
                    quickLogButton
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .sheet(isPresented: $showingLog) {
                ManualLogView { Task { await load() } }
            }
            .onAppear { Task { await load() } }
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ d: Dashboard) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                if let errorText {
                    // Refresh failed but stale data is still on screen.
                    ErrorBanner(message: errorText) { Task { await load() } }
                }

                if d.targets == nil {
                    noTargetsCard
                }

                CalorieSummaryCard(date: d.date, totals: d.totals, targets: d.targets)

                macrosCard(d)
                microsCard(d)
                logsCard(d)
            }
            .padding(.horizontal)
            .padding(.bottom, 88) // keep the floating button clear of the last card
        }
        .refreshable { await load() }
    }

    private var noTargetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No daily targets yet", systemImage: "target")
                .font(.headline)
            Text("Set calorie and macro targets to turn on progress tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Set targets") { router.tab = .targets }
                .buttonStyle(.borderedProminent)
        }
        .flCard()
    }

    private func macrosCard(_ d: Dashboard) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Macros").font(.headline)
            HStack(alignment: .top) {
                MacroGauge(title: "Protein", consumed: d.totals.proteinG, target: d.targets?.proteinG, tint: FLColor.protein)
                MacroGauge(title: "Carbs", consumed: d.totals.carbsG, target: d.targets?.carbsG, tint: FLColor.carbs)
                MacroGauge(title: "Fat", consumed: d.totals.fatG, target: d.targets?.fatG, tint: FLColor.fat)
            }
        }
        .flCard()
    }

    private func microsCard(_ d: Dashboard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Micros").font(.headline)
            MicroProgressRow(title: "Fiber", consumed: d.totals.fiberG, target: d.targets?.fiberG, unit: "g")
            MicroProgressRow(title: "Sodium", consumed: d.totals.sodiumMg, target: d.targets?.sodiumMg, unit: "mg")
            MicroProgressRow(title: "Sugar", consumed: d.totals.sugarG, target: d.targets?.sugarG, unit: "g")
            MicroProgressRow(title: "Potassium", consumed: d.totals.potassiumMg, target: d.targets?.potassiumMg, unit: "mg")
        }
        .flCard()
    }

    private func logsCard(_ d: Dashboard) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Today's Logs").font(.headline)
                Spacer()
                if !d.logs.isEmpty {
                    Text("\(d.logs.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.bottom, d.logs.isEmpty ? 0 : 6)

            if d.logs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 34))
                        .foregroundStyle(.tertiary)
                    Text("Nothing logged yet")
                        .font(.subheadline.weight(.medium))
                    Text("Log macros here, or through ChatGPT or Claude — entries show up either way.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Log food") { showingLog = true }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(d.logs) { log in
                    NavigationLink {
                        FoodLogEditView(log: log) { Task { await load() } }
                    } label: {
                        FoodLogRow(log: log)
                    }
                    .buttonStyle(.plain)
                    if log.id != d.logs.last?.id {
                        Divider()
                    }
                }
            }
        }
        .flCard()
    }

    private var quickLogButton: some View {
        Button {
            showingLog = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .padding(20)
        .accessibilityLabel("Log food")
    }

    private func load() async {
        loading = dashboard == nil
        errorText = nil
        do {
            dashboard = try await client.dashboardToday()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}

// MARK: Calorie summary

struct CalorieSummaryCard: View {
    let date: String
    let totals: NutritionTotals
    let targets: DailyTargets?

    private var target: Double? {
        guard let t = targets?.calories, t > 0 else { return nil }
        return t
    }

    private var remaining: Double? { target.map { $0 - totals.calories } }
    private var over: Bool { (remaining ?? 0) < 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Fmt.friendlyDay(fromISODay: date))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.whole(totals.calories))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("cal eaten")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let target {
                ProgressView(value: min(totals.calories, target), total: target)
                    .tint(over ? FLColor.over : Color.accentColor)

                HStack {
                    metric(over ? "Over by" : "Remaining",
                           value: Fmt.whole(abs(remaining ?? 0)),
                           tint: over ? FLColor.over : .primary)
                    Spacer()
                    metric("Target", value: Fmt.whole(target), tint: .primary)
                }
            } else {
                Text("No calorie target set")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .flCard()
    }

    private func metric(_ label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }
}

// MARK: Log row

struct FoodLogRow: View {
    let log: FoodLog

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(log.label ?? "Food log")
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if log.savedMealId != nil {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("From saved meal")
                    }
                    SourceBadge(source: log.source)
                }
                HStack(spacing: 8) {
                    if log.mealType != .unspecified {
                        Text(log.mealType.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("P \(Fmt.whole(log.proteinG)) · C \(Fmt.whole(log.carbsG)) · F \(Fmt.whole(log.fatG))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.whole(log.calories))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                Text(Fmt.timeOfDay(fromISO: log.loggedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
