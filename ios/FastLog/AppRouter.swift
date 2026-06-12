import Foundation
import Observation

enum AppTab: Hashable {
    case today, meals, weight, targets, settings
}

// Shared tab selection so screens can deep-link each other
// (e.g. the dashboard's "Set targets" CTA jumps to the Targets tab).
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .today
}
