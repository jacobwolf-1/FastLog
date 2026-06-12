import SwiftUI

// App launch → session restore → AuthView (signed out) or MainTabView.
// Developer mode bypasses Supabase auth entirely (manual bearer token).
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AuthManager.self) private var auth

    var body: some View {
        Group {
            if settings.devModeEnabled {
                MainTabView()
            } else {
                switch auth.state {
                case .loading:
                    LaunchView()
                case .signedOut:
                    AuthView()
                case .signedIn:
                    MainTabView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: settings.devModeEnabled)
        .task { await auth.restoreSession() }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            DashboardView()
                .tabItem { Label("Today", systemImage: "chart.bar.fill") }
                .tag(AppTab.today)
            SavedMealsView()
                .tabItem { Label("Meals", systemImage: "fork.knife") }
                .tag(AppTab.meals)
            WeightView()
                .tabItem { Label("Weight", systemImage: "scalemass.fill") }
                .tag(AppTab.weight)
            TargetsView()
                .tabItem { Label("Targets", systemImage: "target") }
                .tag(AppTab.targets)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }
}
