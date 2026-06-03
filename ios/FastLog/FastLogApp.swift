import SwiftUI

@main
struct FastLogApp: App {
    @State private var settings: AppSettings
    @State private var client: APIClient
    @State private var health = HealthKitManager()

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _client = State(initialValue: APIClient(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(client)
                .environment(health)
        }
    }
}
