import Foundation

struct AppConfig {

    // MARK: - Singleton

    static var shared = AppConfig()

    // MARK: - Keys

    private enum Keys {
        static let supabaseUrl = "mmd_supabase_url"
        static let supabaseAnonKey = "mmd_supabase_anon_key"
        static let webApiUrl = "mmd_web_api_url"
        static let webApiAuthToken = "mmd_web_api_auth_token"
        static let useMockRFID = "mmd_use_mock_rfid"
        /// Flag de migração: token manual limpo em Release no primeiro launch.
        static let clearedManualWebApiToken = "mmd_cleared_manual_web_api_token_v1"
    }

    // MARK: - Properties
    //
    // Credenciais do Supabase vem do UserDefaults (Ajustes > Avancado).
    // Sem default embutido: o repo e publico, a anon key nao e versionada.
    // Build de dispositivo local injeta a sua.

    var supabaseUrl: String {
        get { UserDefaults.standard.string(forKey: Keys.supabaseUrl) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.supabaseUrl) }
    }

    var supabaseAnonKey: String {
        get { UserDefaults.standard.string(forKey: Keys.supabaseAnonKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.supabaseAnonKey) }
    }

    var webApiUrl: String {
        get { UserDefaults.standard.string(forKey: Keys.webApiUrl) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.webApiUrl) }
    }

    var webApiAuthToken: String {
        get { UserDefaults.standard.string(forKey: Keys.webApiAuthToken) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.webApiAuthToken) }
    }

    var useMockRFID: Bool {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: Keys.useMockRFID) != nil else {
                #if DEBUG
                return true
                #else
                return false
                #endif
            }

            return defaults.bool(forKey: Keys.useMockRFID)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.useMockRFID)
        }
    }

    // MARK: - Validation

    var isSupabaseConfigured: Bool {
        !supabaseUrl.isEmpty && !supabaseAnonKey.isEmpty
    }

    var isWebApiConfigured: Bool {
        !webApiUrl.isEmpty
    }

    // MARK: - Init

    private init() {
        migrateLegacyManualAuthTokenIfNeeded()
    }

    // MARK: - Migration

    /// Em Release, limpa o JWT colado à mão no primeiro launch desta versão.
    /// Em DEBUG o campo permanece (override de desenvolvimento).
    mutating func migrateLegacyManualAuthTokenIfNeeded() {
        #if DEBUG
        return
        #else
        Self.applyLegacyManualAuthTokenMigration(
            isRelease: true,
            defaults: .standard
        )
        #endif
    }

    /// Lógica pura de migração (testável). Retorna true se limpou o token.
    @discardableResult
    static func applyLegacyManualAuthTokenMigration(
        isRelease: Bool,
        defaults: UserDefaults,
        tokenKey: String = "mmd_web_api_auth_token",
        flagKey: String = "mmd_cleared_manual_web_api_token_v1"
    ) -> Bool {
        guard isRelease else { return false }
        guard !defaults.bool(forKey: flagKey) else { return false }

        let current = defaults.string(forKey: tokenKey) ?? ""
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleared = false
        if !trimmed.isEmpty {
            defaults.removeObject(forKey: tokenKey)
            cleared = true
        }
        defaults.set(true, forKey: flagKey)
        return cleared
    }

    // MARK: - Persistence

    mutating func save(supabaseUrl url: String, anonKey key: String, useMockRFID: Bool) {
        save(
            supabaseUrl: url,
            anonKey: key,
            webApiUrl: webApiUrl,
            webApiAuthToken: webApiAuthToken,
            useMockRFID: useMockRFID
        )
    }

    mutating func save(
        supabaseUrl url: String,
        anonKey key: String,
        webApiUrl apiUrl: String,
        webApiAuthToken token: String,
        useMockRFID: Bool
    ) {
        supabaseUrl = url
        supabaseAnonKey = key
        webApiUrl = apiUrl
        webApiAuthToken = token
        self.useMockRFID = useMockRFID
    }

    func clearSupabaseConfig() {
        UserDefaults.standard.removeObject(forKey: Keys.supabaseUrl)
        UserDefaults.standard.removeObject(forKey: Keys.supabaseAnonKey)
    }

    func clearWebApiConfig() {
        UserDefaults.standard.removeObject(forKey: Keys.webApiUrl)
        UserDefaults.standard.removeObject(forKey: Keys.webApiAuthToken)
    }

}
