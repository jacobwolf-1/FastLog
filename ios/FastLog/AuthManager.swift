import Foundation
import Observation

// Supabase Auth (GoTrue) client implemented directly against the REST endpoints:
// signup, password grant, refresh grant, logout. Deliberately dependency-free —
// the official supabase-swift SDK is a documented follow-up; the token contract
// is identical (the backend just passes the user JWT through to Supabase RLS).

struct SupabaseSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userId: String?
    var email: String?
}

enum AuthError: LocalizedError {
    case notConfigured
    case notSignedIn
    case emailConfirmationRequired
    case server(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured. Add FastLogConfig.plist (see FastLogConfig.example.plist) or use developer mode."
        case .notSignedIn:
            return "You're signed out. Sign in to continue."
        case .emailConfirmationRequired:
            return "Check your email to confirm your account, then sign in."
        case let .server(message):
            return message
        case let .transport(detail):
            return "Network error: \(detail)"
        }
    }
}

@MainActor
@Observable
final class AuthManager {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(SupabaseSession)
    }

    private(set) var state: State = .loading

    var isConfigured: Bool { AppConfig.isSupabaseConfigured }
    var sessionEmail: String? {
        if case let .signedIn(session) = state { return session.email }
        return nil
    }

    private let urlSession: URLSession
    private var refreshTask: Task<SupabaseSession, Error>?
    private static let sessionKey = "supabase.session"

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: Lifecycle

    /// Restores a persisted session on launch. Stale tokens refresh lazily in
    /// `validToken()`, so an expired-but-refreshable session still counts as
    /// signed in here (avoids flashing the auth screen while offline).
    func restoreSession() async {
        guard case .loading = state else { return }
        guard isConfigured,
              let data = Keychain.load(key: Self.sessionKey),
              let saved = try? JSONDecoder().decode(SupabaseSession.self, from: data) else {
            state = .signedOut
            return
        }
        state = .signedIn(saved)
    }

    func signIn(email: String, password: String) async throws {
        let session = try await tokenRequest(
            grant: "password", body: ["email": email, "password": password])
        store(session)
    }

    /// Throws `.emailConfirmationRequired` when the project requires email
    /// confirmation (GoTrue returns a user but no tokens).
    func signUp(email: String, password: String) async throws {
        let data = try await send(path: "signup", body: ["email": email, "password": password])
        guard let session = try Self.parseSession(from: data) else {
            throw AuthError.emailConfirmationRequired
        }
        store(session)
    }

    func signOut() async {
        if case let .signedIn(session) = state {
            // Best-effort server-side revoke; local sign-out happens regardless.
            try? await sendAuthorized(path: "logout", accessToken: session.accessToken)
        }
        Keychain.delete(key: Self.sessionKey)
        refreshTask?.cancel()
        refreshTask = nil
        state = .signedOut
    }

    // MARK: Tokens

    /// Current access token for API calls, refreshing first when near expiry.
    func validToken() async throws -> String {
        guard case let .signedIn(session) = state else { throw AuthError.notSignedIn }
        if session.expiresAt > Date().addingTimeInterval(60) {
            return session.accessToken
        }
        return try await refresh().accessToken
    }

    /// Forces a refresh (single-flight). Used by validToken and by the API
    /// client after an unexpected 401.
    @discardableResult
    func refresh() async throws -> SupabaseSession {
        if let refreshTask {
            return try await refreshTask.value
        }
        guard case let .signedIn(session) = state else { throw AuthError.notSignedIn }
        let task = Task { [weak self] () throws -> SupabaseSession in
            guard let self else { throw AuthError.notSignedIn }
            return try await self.tokenRequest(
                grant: "refresh_token", body: ["refresh_token": session.refreshToken])
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let fresh = try await task.value
            store(fresh)
            return fresh
        } catch let error as AuthError {
            // A rejected refresh token means the session is dead — sign out so
            // the UI shows the auth screen instead of failing every call.
            if case .server = error {
                Keychain.delete(key: Self.sessionKey)
                state = .signedOut
                throw AuthError.notSignedIn
            }
            throw error
        }
    }

    private func store(_ session: SupabaseSession) {
        if let data = try? JSONEncoder().encode(session) {
            Keychain.save(data, key: Self.sessionKey)
        }
        state = .signedIn(session)
    }

    // MARK: GoTrue plumbing

    private struct TokenResponse: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let expiresIn: Double?
        let expiresAt: Double?
        let user: UserInfo?

        struct UserInfo: Decodable {
            let id: String?
            let email: String?
        }

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case expiresAt = "expires_at"
            case user
        }
    }

    private struct GoTrueErrorBody: Decodable {
        let errorDescription: String?
        let msg: String?
        let message: String?
        let error: String?

        enum CodingKeys: String, CodingKey {
            case errorDescription = "error_description"
            case msg, message, error
        }

        var best: String? { errorDescription ?? msg ?? message ?? error }
    }

    private func tokenRequest(grant: String, body: [String: String]) async throws -> SupabaseSession {
        let data = try await send(path: "token?grant_type=\(grant)", body: body)
        guard let session = try Self.parseSession(from: data) else {
            throw AuthError.server("Sign-in response did not include a session.")
        }
        return session
    }

    private static func parseSession(from data: Data) throws -> SupabaseSession? {
        let response: TokenResponse
        do {
            response = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw AuthError.server("Could not read the auth response.")
        }
        guard let access = response.accessToken, let refresh = response.refreshToken else {
            return nil
        }
        let expiresAt = response.expiresAt.map { Date(timeIntervalSince1970: $0) }
            ?? Date().addingTimeInterval(response.expiresIn ?? 3600)
        return SupabaseSession(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: expiresAt,
            userId: response.user?.id,
            email: response.user?.email
        )
    }

    @discardableResult
    private func send(path: String, body: [String: String]) async throws -> Data {
        guard let baseURL = AppConfig.supabaseURL, let anonKey = AppConfig.supabaseAnonKey,
              let url = URL(string: "\(baseURL)/auth/v1/\(path)") else {
            throw AuthError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func sendAuthorized(path: String, accessToken: String) async throws {
        guard let baseURL = AppConfig.supabaseURL, let anonKey = AppConfig.supabaseAnonKey,
              let url = URL(string: "\(baseURL)/auth/v1/\(path)") else {
            throw AuthError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw AuthError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.transport("Missing HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(GoTrueErrorBody.self, from: data))?.best
                ?? "Authentication failed (\(http.statusCode))."
            throw AuthError.server(message)
        }
        return data
    }
}
