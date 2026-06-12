import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AuthManager.self) private var auth
    @Environment(APIClient.self) private var client
    @Environment(HealthKitManager.self) private var health

    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false
    @State private var showingDevOptions = false
    @State private var signingOut = false

    var body: some View {
        @Bindable var settings = settings
        return NavigationStack {
            Form {
                accountSection

                Section {
                    TextField(AppConfig.defaultAPIBaseURL, text: $settings.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.callout)
                    Button {
                        Task { await testConnection() }
                    } label: {
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
                } header: {
                    Text("Backend")
                } footer: {
                    Text("All data lives in the FastLog backend. The default is the deployed production server.")
                }

                Section {
                    LabeledContent("Body mass read", value: healthStatusText)
                    if health.isAvailable && health.status == .notDetermined {
                        Button("Request access") { Task { await health.requestReadAccess() } }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Read-only, on this device only. FastLog never writes to Apple Health, and AI integrations can't touch it. iOS doesn't report whether read access was granted; the Weight screen shows whether a sample was found.")
                }

                Section {
                    Button("Developer options") { showingDevOptions = true }
                    if settings.devModeEnabled {
                        Label("Manual token mode is on", systemImage: "wrench.and.screwdriver.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                } footer: {
                    Text("Manual bearer-token mode for local backend development.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingDevOptions) {
                DeveloperOptionsView()
            }
            .onAppear { health.refreshStatus() }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if settings.devModeEnabled {
                LabeledContent("Mode", value: "Developer token")
            } else if case .signedIn = auth.state {
                LabeledContent("Signed in as", value: auth.sessionEmail ?? "Supabase user")
                Button(role: .destructive) {
                    Task {
                        signingOut = true
                        await auth.signOut()
                        signingOut = false
                    }
                } label: {
                    if signingOut { ProgressView() } else { Text("Sign Out") }
                }
                .disabled(signingOut)
            } else {
                LabeledContent("Status", value: "Signed out")
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
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
