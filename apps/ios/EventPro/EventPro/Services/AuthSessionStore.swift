import Foundation

// MARK: - AuthError

enum AuthError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case invalidCredentials
    case sessionExpired
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase não configurado. Acesse Ajustes para inserir URL e chave."
        case .notAuthenticated:
            return "Faça login para continuar."
        case .invalidCredentials:
            return "Usuário ou senha incorretos."
        case .sessionExpired:
            return "Sessão expirada. Faça login novamente."
        case .network(let error):
            return "Erro de rede: \(error.localizedDescription)"
        }
    }
}

// MARK: - AuthSessionStore

/// Sessão Supabase Auth (GoTrue) com Keychain + refresh single-flight.
/// URLSession puro, sem SDK.
actor AuthSessionStore {

    static let shared = AuthSessionStore()

    struct Session: Codable, Equatable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
        let userEmail: String?
    }

    // MARK: - Dependencies

    private let storage: any SessionStoring
    private let urlSession: URLSession
    private let configProvider: @Sendable () -> (url: String, anonKey: String)

    /// Margem proativa antes de `expiresAt` (cobre clock skew).
    private let proactiveRefreshMargin: TimeInterval = 120

    private var session: Session?
    /// Single-flight: chamadas concorrentes aguardam a mesma Task de refresh.
    private var refreshTask: Task<String, Error>?

    // MARK: - Init

    init(
        storage: any SessionStoring = KeychainStore(service: "com.emdash.mmdestoque.auth"),
        urlSession: URLSession = .shared,
        configProvider: @escaping @Sendable () -> (url: String, anonKey: String) = {
            (AppConfig.shared.supabaseUrl, AppConfig.shared.supabaseAnonKey)
        }
    ) {
        self.storage = storage
        self.urlSession = urlSession
        self.configProvider = configProvider
        self.session = Self.loadSession(from: storage)
    }

    // MARK: - Public API

    var hasSession: Bool {
        session != nil
    }

    var sessionEmail: String? {
        session?.userEmail
    }

    /// identifier sem "@" vira "\(identifier)@mmd.local" (espelha normalizeLoginIdentifier do web).
    func signIn(identifier: String, password: String) async throws {
        let config = configProvider()
        guard !config.url.isEmpty, !config.anonKey.isEmpty else {
            throw AuthError.notConfigured
        }

        let email = Self.normalizeLoginIdentifier(identifier)
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }

        let body: [String: String] = [
            "email": email,
            "password": password
        ]

        let data = try await postToken(
            grantType: "password",
            body: body,
            baseURL: config.url,
            anonKey: config.anonKey
        )

        let newSession = try Self.decodeSession(from: data)
        try persist(newSession)
    }

    func signOut() {
        session = nil
        refreshTask?.cancel()
        refreshTask = nil
        try? storage.delete()
    }

    /// Token válido pra Authorization. Refresh proativo se expira em <120s.
    /// Single-flight: chamadas concorrentes aguardam a MESMA Task de refresh.
    func validAccessToken() async throws -> String {
        guard let current = session else {
            throw AuthError.notAuthenticated
        }

        let needsRefresh = current.expiresAt.timeIntervalSinceNow < proactiveRefreshMargin
        if !needsRefresh {
            return current.accessToken
        }

        return try await performRefresh(using: current.refreshToken)
    }

    /// Refresh forçado após um 401 (retry reativo). Também single-flight.
    func refreshedAccessToken() async throws -> String {
        guard let current = session else {
            throw AuthError.notAuthenticated
        }
        return try await performRefresh(using: current.refreshToken)
    }

    // MARK: - Refresh (single-flight)

    private func performRefresh(using refreshToken: String) async throws -> String {
        if let existing = refreshTask {
            return try await existing.value
        }

        let task = Task<String, Error> {
            try await self.executeRefresh(refreshToken: refreshToken)
        }
        refreshTask = task

        do {
            let token = try await task.value
            refreshTask = nil
            return token
        } catch {
            refreshTask = nil
            throw error
        }
    }

    private func executeRefresh(refreshToken: String) async throws -> String {
        let config = configProvider()
        guard !config.url.isEmpty, !config.anonKey.isEmpty else {
            throw AuthError.notConfigured
        }

        do {
            let data = try await postToken(
                grantType: "refresh_token",
                body: ["refresh_token": refreshToken],
                baseURL: config.url,
                anonKey: config.anonKey
            )
            let newSession = try Self.decodeSession(from: data)
            try persist(newSession)
            return newSession.accessToken
        } catch AuthError.invalidCredentials {
            // Refresh 400/401: sessão morta, limpar.
            signOut()
            throw AuthError.sessionExpired
        } catch let error as AuthError {
            if case .sessionExpired = error {
                signOut()
            }
            throw error
        }
    }

    // MARK: - GoTrue HTTP

    private func postToken(
        grantType: String,
        body: [String: String],
        baseURL: String,
        anonKey: String
    ) async throws -> Data {
        let sanitized = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard var components = URLComponents(string: sanitized + "/auth/v1/token") else {
            throw AuthError.notConfigured
        }
        components.queryItems = [URLQueryItem(name: "grant_type", value: grantType)]

        guard let url = components.url else {
            throw AuthError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw AuthError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.network(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 400, 401:
            throw AuthError.invalidCredentials
        default:
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw AuthError.network(
                NSError(domain: "AuthSessionStore", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: message
                ])
            )
        }
    }

    // MARK: - Persistence

    private func persist(_ newSession: Session) throws {
        session = newSession
        let data = try JSONEncoder().encode(newSession)
        try storage.save(data)
    }

    private static func loadSession(from storage: any SessionStoring) -> Session? {
        guard let data = try? storage.load() else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    // MARK: - Decoding

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
        let user: TokenUser?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case user
        }
    }

    private struct TokenUser: Decodable {
        let email: String?
    }

    private static func decodeSession(from data: Data) throws -> Session {
        let decoded: TokenResponse
        do {
            decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw AuthError.network(error)
        }

        return Session(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expiresIn)),
            userEmail: decoded.user?.email
        )
    }

    // MARK: - Identifier normalize (espelha web)

    static func normalizeLoginIdentifier(_ raw: String) -> String {
        let identifier = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !identifier.isEmpty else { return "" }
        if identifier.contains("@") { return identifier }

        // username simples: só alfanumérico + . _ -
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
        if identifier.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return "\(identifier)@mmd.local"
        }
        return identifier
    }
}
