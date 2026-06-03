import SwiftUI
import Charts

struct WeightView: View {
    @Environment(APIClient.self) private var client

    @State private var range = "week"
    @State private var trend: WeightTrend?
    @State private var loading = false
    @State private var errorText: String?
    @State private var entering = false

    private let ranges = ["week", "month", "year"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Range", selection: $range) {
                    ForEach(ranges, id: \.self) { Text($0.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    Section { chart }
                    Section("Summary") {
                        LabeledContent("Average", value: Fmt.weight(trend?.averageWeightLb))
                        LabeledContent("Change", value: changeText)
                        LabeledContent("Entries", value: "\(trend?.points.count ?? 0)")
                    }
                    if let errorText {
                        Section { Text(errorText).foregroundStyle(.red).font(.subheadline) }
                    }
                }
            }
            .navigationTitle("Weight")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { entering = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $entering) {
                WeightEntryView { Task { await load() } }
            }
            .task { await load() }
            .onChange(of: range) { _, _ in Task { await load() } }
        }
    }

    @ViewBuilder
    private var chart: some View {
        if let points = trend?.points, !points.isEmpty {
            Chart(points) { point in
                if let d = Fmt.date(fromISO: point.measuredAt) {
                    LineMark(x: .value("Date", d), y: .value("Weight", point.weightLb))
                    PointMark(x: .value("Date", d), y: .value("Weight", point.weightLb))
                }
            }
            .frame(height: 220)
        } else if loading {
            ProgressView().frame(maxWidth: .infinity).frame(height: 220)
        } else {
            Text("No weight entries in this range.")
                .foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 220)
        }
    }

    private var changeText: String {
        guard let c = trend?.changeLb else { return "—" }
        let sign = c > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", c)) lb"
    }

    private func load() async {
        loading = true
        errorText = nil
        do {
            trend = try await client.weightTrend(range: range)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}

// Manual weight entry, with an optional one-tap fill from HealthKit body mass.
struct WeightEntryView: View {
    @Environment(APIClient.self) private var client
    @Environment(HealthKitManager.self) private var health
    @Environment(\.dismiss) private var dismiss

    var onSaved: () -> Void

    @State private var weight = ""
    @State private var saving = false
    @State private var errorText: String?
    @State private var healthNote: String?

    private var valid: Bool { (weight.optionalDouble ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NumberField(title: "Weight", unit: "lb", text: $weight)
                }
                if health.isAvailable {
                    Section {
                        Button {
                            Task { await fillFromHealth() }
                        } label: {
                            Label("Fill from Apple Health", systemImage: "heart.fill")
                        }
                        if let healthNote {
                            Text(healthNote).font(.caption).foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Reads your latest body mass from Apple Health. Saved as a manual entry in FastLog; nothing is written back to Apple Health.")
                    }
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.subheadline) }
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(!valid || saving)
                }
            }
        }
    }

    private func fillFromHealth() async {
        healthNote = nil
        await health.requestReadAccess()
        if let lb = await health.latestBodyMassLb() {
            weight = String(format: "%.1f", lb)
            healthNote = "Filled from Apple Health."
        } else {
            healthNote = "No body-mass sample found in Apple Health."
        }
    }

    private func save() async {
        saving = true
        errorText = nil
        // source=manual: a normal app write, never marked as an AI/Health write.
        let payload = CreateWeightEntryPayload(weightLb: weight.optionalDouble ?? 0, source: "manual")
        do {
            _ = try await client.createWeightEntry(payload)
            onSaved()
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        saving = false
    }
}
