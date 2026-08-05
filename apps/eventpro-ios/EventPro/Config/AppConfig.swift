import Foundation

/// Configuração local do app, persistida em `UserDefaults`.
///
/// Não guarda credencial de usuário: token de acesso e refresh token vivem no
/// Keychain (`KeychainStore`), gerenciados por `AuthService`. Aqui ficam só
/// endpoints e preferência de leitor.
struct AppConfig {

    // MARK: - Singleton

    static var shared = AppConfig()

    // MARK: - Keys

    private enum Keys {
        static let supabaseUrl = "eventpro_supabase_url"
        static let supabaseAnonKey = "eventpro_supabase_anon_key"
        static let webApiUrl = "eventpro_web_api_url"
        static let useMockRFID = "eventpro_use_mock_rfid"
        static let antennaPowerDeciDbm = "eventpro_antenna_power_decidbm"
    }

    // MARK: - Endpoints
    //
    // Credenciais do Supabase vêm do UserDefaults (Ajustes). Sem default
    // embutido: o repo é público e a anon key não é versionada.

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

    // MARK: - Leitor

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
        set { UserDefaults.standard.set(newValue, forKey: Keys.useMockRFID) }
    }

    /// Potência de antena desejada, em décimos de dBm (270 = 27,0 dBm).
    ///
    /// Conferência de packing por proximidade depende de potência baixa: no
    /// máximo, o RFD40 lê o galpão inteiro e o bucket de "extras" fica inútil.
    /// O valor é limitado depois pela faixa real do leitor
    /// (`srfidGetReaderCapabilitiesInfo` devolve min, max e passo).
    var antennaPowerDeciDbm: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Keys.antennaPowerDeciDbm)
            return stored == 0 ? AppConfig.defaultAntennaPowerDeciDbm : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.antennaPowerDeciDbm) }
    }

    static let defaultAntennaPowerDeciDbm = 200
    static let minAntennaPowerDeciDbm = 50
    static let maxAntennaPowerDeciDbm = 300

    // MARK: - Validation

    var isSupabaseConfigured: Bool {
        !supabaseUrl.isEmpty && !supabaseAnonKey.isEmpty
    }

    var isWebApiConfigured: Bool {
        !webApiUrl.isEmpty
    }

    // MARK: - Init

    private init() {}

    // MARK: - Persistence

    mutating func save(
        supabaseUrl url: String,
        anonKey key: String,
        webApiUrl apiUrl: String,
        useMockRFID: Bool
    ) {
        supabaseUrl = url
        supabaseAnonKey = key
        webApiUrl = apiUrl
        self.useMockRFID = useMockRFID
    }

    func clearSupabaseConfig() {
        UserDefaults.standard.removeObject(forKey: Keys.supabaseUrl)
        UserDefaults.standard.removeObject(forKey: Keys.supabaseAnonKey)
    }

    func clearWebApiConfig() {
        UserDefaults.standard.removeObject(forKey: Keys.webApiUrl)
    }
}

// MARK: - URL helpers

extension AppConfig {

    /// Base sem barra final, para concatenar com um path que começa em `/`.
    static func sanitizedBase(_ raw: String) -> String {
        var base = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") {
            base.removeLast()
        }
        return base
    }
}
