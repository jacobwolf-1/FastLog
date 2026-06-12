import SwiftUI

// Signed-out entry point: Supabase email/password sign-in and sign-up.
// Developer options (manual token mode) stay reachable but discreet.
struct AuthView: View {
    @Environment(AuthManager.self) private var auth

    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case signUp = "Create Account"
        var id: String { rawValue }
    }

    private enum Field { case email, password }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var working = false
    @State private var errorText: String?
    @State private var noticeText: String?
    @State private var showingDevOptions = false
    @FocusState private var focus: Field?

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !working
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                    .padding(.top, 72)

                if auth.isConfigured {
                    form
                } else {
                    notConfiguredCard
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button("Developer options") { showingDevOptions = true }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingDevOptions) {
            DeveloperOptionsView()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
            Text("FastLog")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("Fast, minimal macro logging.\nYou bring the numbers — we keep the score.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var form: some View {
        VStack(spacing: 16) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 0) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                    .padding(14)
                Divider()
                SecureField("Password (6+ characters)", text: $password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if canSubmit { Task { await submit() } } }
                    .padding(14)
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let noticeText {
                Label(noticeText, systemImage: "envelope.badge")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if working {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode == .signIn ? "Sign In" : "Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit)
        }
        .onChange(of: mode) { _, _ in
            errorText = nil
            noticeText = nil
        }
    }

    private var notConfiguredCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Supabase not configured", systemImage: "key.slash")
                .font(.headline)
            Text("Copy `FastLogConfig.example.plist` to `FastLogConfig.plist` in the Xcode project and fill in your Supabase project URL and anon key. Until then, you can use developer mode below with a manual bearer token.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .flCard()
    }

    private func submit() async {
        working = true
        errorText = nil
        noticeText = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        do {
            switch mode {
            case .signIn:
                try await auth.signIn(email: trimmedEmail, password: password)
            case .signUp:
                try await auth.signUp(email: trimmedEmail, password: password)
            }
        } catch AuthError.emailConfirmationRequired {
            noticeText = AuthError.emailConfirmationRequired.errorDescription
            mode = .signIn
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        working = false
    }
}

// Manual bearer-token mode for local memory-mode backend development.
// Reachable from AuthView (signed out) and from Settings.
struct DeveloperOptionsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        return NavigationStack {
            Form {
                Section {
                    Toggle("Use manual token", isOn: $settings.devModeEnabled)
                } footer: {
                    Text("Bypasses Supabase sign-in and sends the token below as `Authorization: Bearer <token>`. For local memory-mode backends use dev:<user-id>[:email].")
                }
                Section("Backend base URL") {
                    TextField(AppConfig.defaultAPIBaseURL, text: $settings.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Use local dev server") {
                        settings.baseURL = AppSettings.defaultLocalBaseURL
                    }
                    .font(.subheadline)
                }
                Section("Manual token") {
                    TextField(AppSettings.defaultDevToken, text: $settings.devToken, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout.monospaced())
                }
            }
            .navigationTitle("Developer Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
