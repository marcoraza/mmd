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
    }

    // MARK: - Properties

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

    private init() {}

    // MARK: - Persistence

    mutating func save(supabaseUrl url: String, anonKey key: String, useMockRFID: Bool) {
        save(supabaseUrl: url, anonKey: key, webApiUrl: webApiUrl, useMockRFID: useMockRFID)
    }

    mutating func save(supabaseUrl url: String, anonKey key: String, webApiUrl apiUrl: String, useMockRFID: Bool) {
        save(
            supabaseUrl: url,
            anonKey: key,
            webApiUrl: apiUrl,
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
