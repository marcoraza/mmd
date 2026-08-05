import Foundation
import Combine

// MARK: - Erros

enum AuthError: LocalizedError, Equatable {
    case notConfigured
    case invalidCredentials
    case invalidResponse
    case network(String)
    case server(status: Int, message: String?)
    case noSession
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase não configurado. Preencha URL e chave anônima em Ajustes."
        case .invalidCredentials:
            return "E-mail ou senha incorretos."
        case .invalidResponse:
            return "Resposta de autenticação inesperada."
        case .network(let detail):
            return "Erro de rede na autenticação: \(detail)"
        case .server(let status, let message):
            return message ?? "Falha na autenticação (HTTP \(status))."
        case .noSession:
            return "Sessão expirada. Faça login novamente."
        case .refreshFailed(let detail):
            return "Não foi possível renovar a sessão: \(detail)"
        }
    }
}

// MARK: - Sessão

struct AuthSession: Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userId: String?
    var userEmail: String?

    /// Margem antes do vencimento: renova cedo para não perder uma operação de
    /// campo por 5 segundos de atraso de relógio.
    static let refreshSkew: TimeInterval = 60

    func isExpired(now: Date = Date(), skew: TimeInterval = AuthSession.refreshSkew) -> Bool {
        now.addingTimeInterval(skew) >= expiresAt
    }
}

// MARK: - DTOs GoTrue

private struct GoTrueTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int?
    let expiresAt: Int?
    let user: GoTrueUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case user
    }
}

private struct GoTrueUser: Decodable {
    let id: String?
    let email: String?
}

private struct GoTrueError: Decodable {
    let error: String?
    let errorDescription: String?
    let message: String?
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case message
        case msg
    }

    var displayMessage: String? {
        errorDescription ?? message ?? msg ?? error
    }
}

// MARK: - AuthService

/// Autenticação Supabase de verdade: login por senha no GoTrue REST, tokens no
/// Keychain e refresh automático antes de cada requisição.
///
/// Sem SDK: `URLSession` direto contra `/auth/v1/token`, no mesmo espírito do
/// `APIClient`. O `APIClient` pede o token válido aqui em vez de ler um JWT
/// colado à mão em Ajustes (correção do achado 3.3 da auditoria).
@MainActor
final class AuthService: ObservableObject {

    // MARK: - Published

    @Published private(set) var session: AuthSession?
    @Published private(set) var isAuthenticating = false
    @Published var lastError: AuthError?

    var isAuthenticated: Bool { session != nil }
    var currentUserEmail: String? { session?.userEmail }

    // MARK: - Dependências

    private let session_: URLSession
    private let keychain: KeychainStore

    /// Uma renovação por vez: várias telas podendo disparar refresh ao mesmo
    /// tempo é o jeito clássico de invalidar o refresh token (o GoTrue rotaciona
    /// o refresh token a cada uso).
    private var refreshTask: Task<AuthSession, Error>?

    private var baseURL: String { AppConfig.shared.supabaseUrl }
    private var anonKey: String { AppConfig.shared.supabaseAnonKey }

    // MARK: - Init

    init(urlSession: URLSession = .shared, keychain: KeychainStore = KeychainStore()) {
        self.session_ = urlSession
        self.keychain = keychain
        self.session = Self.loadSession(from: keychain)
    }

    // MARK: - Login / logout

    func signIn(email: String, password: String) async throws {
        guard AppConfig.shared.isSupabaseConfigured else {
            throw AuthError.notConfigured
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }

        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        do {
            let body = try JSONSerialization.data(
                withJSONObject: ["email": trimmedEmail, "password": password]
            )
            let response = try await postToken(
                grantType: "password",
                body: body
            )
            let newSession = Self.makeSession(from: response)
            persist(newSession)
            session = newSession
        } catch let error as AuthError {
            lastError = error
            throw error
        }
    }

    func signOut() {
        refreshTask?.cancel()
        refreshTask = nil

        // Best-effort: avisa o servidor, mas o estado local sai na hora. Um
        // logout que depende de rede deixa o operador preso num galpão sem sinal.
        if let token = session?.accessToken, AppConfig.shared.isSupabaseConfigured {
            let base = AppConfig.sanitizedBase(baseURL)
            let key = anonKey
            let urlSession = session_
            if let url = URL(string: base + "/auth/v1/logout") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(key, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                Task.detached { _ = try? await urlSession.data(for: request) }
            }
        }

        keychain.removeAll()
        session = nil
        lastError = nil
    }

    // MARK: - Token válido

    /// Token de acesso válido, renovando quando estiver perto de vencer.
    /// É o que o `APIClient` chama antes de cada requisição autenticada.
    func validAccessToken() async throws -> String {
        guard let current = session else {
            throw AuthError.noSession
        }
        guard current.isExpired() else {
            return current.accessToken
        }
        return try await refresh().accessToken
    }

    /// Renova a sessão. Chamadas concorrentes compartilham a mesma tarefa.
    @discardableResult
    func refresh() async throws -> AuthSession {
        if let existing = refreshTask {
            return try await existing.value
        }

        guard let current = session else {
            throw AuthError.noSession
        }
        guard AppConfig.shared.isSupabaseConfigured else {
            throw AuthError.notConfigured
        }

        let task = Task<AuthSession, Error> { [weak self] in
            guard let self else { throw AuthError.noSession }
            let body = try JSONSerialization.data(
                withJSONObject: ["refresh_token": current.refreshToken]
            )
            let response = try await self.postToken(grantType: "refresh_token", body: body)
            var renewed = Self.makeSession(from: response)
            // O GoTrue pode omitir dados de usuário na renovação.
            renewed.userId = renewed.userId ?? current.userId
            renewed.userEmail = renewed.userEmail ?? current.userEmail
            return renewed
        }

        refreshTask = task

        do {
            let renewed = try await task.value
            refreshTask = nil
            persist(renewed)
            session = renewed
            return renewed
        } catch {
            refreshTask = nil
            let authError: AuthError
            if let error = error as? AuthError {
                authError = error
            } else {
                authError = .refreshFailed(error.localizedDescription)
            }

            // Refresh token recusado é sessão morta: limpa e força login novo.
            if case .server(let status, _) = authError, status == 400 || status == 401 {
                keychain.removeAll()
                session = nil
            }

            lastError = authError
            throw authError
        }
    }

    // MARK: - HTTP

    private func postToken(grantType: String, body: Data) async throws -> GoTrueTokenResponse {
        let base = AppConfig.sanitizedBase(baseURL)
        guard var components = URLComponents(string: base + "/auth/v1/token") else {
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session_.data(for: request)
        } catch {
            throw AuthError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let decoded = try? JSONDecoder().decode(GoTrueError.self, from: data)
            if http.statusCode == 400 && grantType == "password" {
                throw AuthError.invalidCredentials
            }
            throw AuthError.server(status: http.statusCode, message: decoded?.displayMessage)
        }

        guard let token = try? JSONDecoder().decode(GoTrueTokenResponse.self, from: data) else {
            throw AuthError.invalidResponse
        }
        return token
    }

    // MARK: - Persistência

    private static func makeSession(from response: GoTrueTokenResponse) -> AuthSession {
        let expiresAt: Date = {
            if let absolute = response.expiresAt {
                return Date(timeIntervalSince1970: TimeInterval(absolute))
            }
            // Default do GoTrue é 3600 s; sem o campo, assume o mesmo.
            return Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))
        }()

        return AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: expiresAt,
            userId: response.user?.id,
            userEmail: response.user?.email
        )
    }

    private func persist(_ session: AuthSession) {
        keychain.set(session.accessToken, for: .accessToken)
        keychain.set(session.refreshToken, for: .refreshToken)
        keychain.set(String(session.expiresAt.timeIntervalSince1970), for: .expiresAt)
        keychain.set(session.userId, for: .userId)
        keychain.set(session.userEmail, for: .userEmail)
    }

    private static func loadSession(from keychain: KeychainStore) -> AuthSession? {
        guard
            let accessToken = keychain.string(for: .accessToken),
            let refreshToken = keychain.string(for: .refreshToken),
            let expiresRaw = keychain.string(for: .expiresAt),
            let expires = TimeInterval(expiresRaw)
        else {
            return nil
        }

        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date(timeIntervalSince1970: expires),
            userId: keychain.string(for: .userId),
            userEmail: keychain.string(for: .userEmail)
        )
    }
}
