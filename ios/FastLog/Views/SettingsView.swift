import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(APIClient.self) private var client
    @Environment(HealthKitManager.self) private var health

    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    var body: some View {
        @Bindable var settings = settings
        return NavigationStack {
            Form {
                Section {
                    TextField("http://localhost:8787", text: $settings.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Backend base URL")
                } footer: {
                    Text("For Simulator use http://localhost:8787. On a physical device use your Mac's LAN IP, e.g. http://192.168.1.10:8787.")
                }

                Section {
                    TextField("dev:user-a:user-a@example.test", text: $settings.token, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Auth token")
                } footer: {
                    Text("Sent as `Authorization: Bearer <token>`. In memory mode use dev:<user-id>[:email].")
                }

                Section {
                    Button { Task { await testConnection() } } label: {
                        HStack {
                            Text("Test connection")
                            Spacer()
                            if testing { ProgressView() }
                        }
                    }
                    .disabled(testing)
                    if let testResult {
                        Label(testResult, systemImage: testOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(testOK ? .green : .red)
                            .font(.subheadline)
                    }
                }

                Section {
                    LabeledContent("Body mass read", value: healthStatusText)
                    if health.isAvailable && health.status == .notDetermined {
                        Button("Request access") { Task { await health.requestReadAccess() } }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Read-only. iOS does not report whether read access was granted; the Weight screen shows whether a sample was actually found. Nothing is written to Apple Health.")
                }

                Section {
                    Button("Reset to defaults") {
                        settings.baseURL = AppSettings.defaultBaseURL
                        settings.token = AppSettings.defaultToken
                        testResult = nil
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { health.refreshStatus() }
        }
    }

    private var healthStatusText: String {
        switch health.status {
        case .unavailable: return "Unavailable"
        case .notDetermined: return "Not requested"
        case .requested: return "Requested"
        }
    }

    private func testConnection() async {
        testing = true
        testResult = nil
        do {
            let d = try await client.dashboardToday()
            testOK = true
            testResult = "Connected. \(d.logs.count) log(s) today."
        } catch {
            testOK = false
            testResult = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        testing = false
    }
}
