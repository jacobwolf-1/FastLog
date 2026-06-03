import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "chart.bar.fill") }
            SavedMealsView()
                .tabItem { Label("Meals", systemImage: "fork.knife") }
            WeightView()
                .tabItem { Label("Weight", systemImage: "scalemass.fill") }
            TargetsView()
                .tabItem { Label("Targets", systemImage: "target") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
