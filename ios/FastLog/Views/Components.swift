import SwiftUI

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

// A reusable numeric form row that binds to an optional Double via text.
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
                .monospacedDigit()
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
