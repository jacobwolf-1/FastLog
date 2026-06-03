import SwiftUI

// A labeled macro/micro progress bar: consumed vs. target.
struct MacroProgressRow: View {
    let title: String
    let consumed: Double
    let target: Double?
    let unit: String

    private var fraction: Double {
        guard let target, target > 0 else { return 0 }
        return min(consumed / target, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: fraction)
                .tint(fraction >= 1 ? .orange : .accentColor)
        }
    }

    private var detail: String {
        let c = Int(consumed.rounded())
        if let target, target > 0 {
            return "\(c) / \(Int(target.rounded())) \(unit)"
        }
        return "\(c) \(unit)"
    }
}

// Big "calories" headline card for the dashboard.
struct CaloriesCard: View {
    let consumed: Double
    let remaining: Double
    let target: Double?

    var body: some View {
        VStack(spacing: 8) {
            Text("\(Int(consumed.rounded()))")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("calories consumed").font(.subheadline).foregroundStyle(.secondary)
            Divider()
            HStack {
                metric("Remaining", value: Int(remaining.rounded()))
                Spacer()
                metric("Target", value: target.map { Int($0.rounded()) })
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ label: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value.map(String.init) ?? "—")
                .font(.title3.weight(.semibold)).monospacedDigit()
        }
    }
}

// Inline error + retry strip used by data screens.
struct ErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Button("Retry", action: retry).buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// A reusable numeric field that binds to an optional Double via text.
struct NumberField: View {
    let title: String
    let unit: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            Text(unit).foregroundStyle(.secondary).frame(width: 32, alignment: .leading)
        }
    }
}

extension String {
    /// Parses a user-entered number; empty/invalid → nil.
    var optionalDouble: Double? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }
}

extension Double {
    var trimmedString: String {
        self == rounded() ? String(Int(self)) : String(self)
    }
}
