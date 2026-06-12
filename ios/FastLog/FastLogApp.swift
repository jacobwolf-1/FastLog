import SwiftUI

@main
struct FastLogApp: App {
    @State private var settings: AppSettings
    @State private var auth: AuthManager
    @State private var client: APIClient
    @State private var health = HealthKitManager()
    @State private var router = AppRouter()

    init() {
        let settings = AppSettings()
        let auth = AuthManager()
        _settings = State(initialValue: settings)
        _auth = State(initialValue: auth)
        _client = State(initialValue: APIClient(settings: settings, auth: auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(auth)
                .environment(client)
                .environment(health)
                .environment(router)
        }
    }
}
