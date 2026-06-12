import SwiftUI

// Shared visual language: restrained, data-dense, quantified-self — not a
// cartoon diet app. Cards on grouped background, monospaced digits, one accent.

enum FLColor {
    static let protein = Color.teal
    static let carbs = Color.orange
    static let fat = Color.purple
    static let over = Color.red
}

// MARK: Cards

private struct FLCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func flCard() -> some View { modifier(FLCard()) }
}

// MARK: Source badge

// Small capsule identifying non-manual entries (ChatGPT/Claude/etc.).
// Manual logs render nothing — badges should mean "this came from elsewhere".
struct SourceBadge: View {
    let source: String

    private var info: (label: String, tint: Color)? {
        switch source {
        case "chatgpt": return ("ChatGPT", .green)
        case "claude": return ("Claude", .orange)
        case "shortcut": return ("Shortcut", .indigo)
        case "import": return ("Import", .gray)
        default: return nil
        }
    }

    var body: some View {
        if let info {
            Text(info.label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Capsule().fill(info.tint.opacity(0.16)))
                .foregroundStyle(info.tint)
        }
    }
}

// MARK: Meal type chips

// Tappable capsules for breakfast/lunch/dinner/snack. Tapping the selected
// chip deselects back to .unspecified — meal type stays optional by design.
struct MealTypeChips: View {
    @Binding var selection: MealType

    private let options: [MealType] = [.breakfast, .lunch, .dinner, .snack]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                let selected = selection == option
                Button {
                    selection = selected ? .unspecified : option
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(selected
                                ? Color.accentColor.opacity(0.18)
                                : Color(.tertiarySystemGroupedBackground)))
                        .foregroundStyle(selected ? Color.accentColor : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Progress

// Circular macro gauge (native Gauge — no custom drawing). Falls back to a
// plain value when no target exists.
struct MacroGauge: View {
    let title: String
    let consumed: Double
    let target: Double?
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            if let target, target > 0 {
                Gauge(value: min(consumed, target), in: 0...target) {
                    Text(title)
                } currentValueLabel: {
                    Text(Fmt.whole(consumed))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(consumed > target ? FLColor.over : tint)
            } else {
                Text(Fmt.whole(consumed))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(tint.opacity(0.12)))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.caption.weight(.medium))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var detail: String {
        if let target, target > 0 {
            return "\(Fmt.whole(consumed)) / \(Fmt.whole(target)) g"
        }
        return "\(Fmt.whole(consumed)) g · no target"
    }
}

// Compact linear bar for micros (fiber/sodium/sugar/potassium).
struct MicroProgressRow: View {
    let title: String
    let consumed: Double
    let target: Double?
    let unit: String

    private var fraction: Double {
        guard let target, target > 0 else { return 0 }
        return min(consumed / target, 1)
    }

    private var over: Bool {
        guard let target, target > 0 else { return false }
        return consumed > target
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: fraction)
                .tint(over ? FLColor.over : Color.accentColor)
        }
    }

    private var detail: String {
        if let target, target > 0 {
            return "\(Fmt.whole(consumed)) / \(Fmt.whole(target)) \(unit)"
        }
        return "\(Fmt.whole(consumed)) \(unit)"
    }
}
