import Foundation

struct AppConfig {

    // MARK: - Singleton

    static var shared = AppConfig()

    // MARK: - Keys

    private enum Keys {
        static let supabaseUrl = "mmd_supabase_url"
        static let supabaseAnonKey = "mmd_supabase_anon_key"
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

    // MARK: - Init

    private init() {}

    // MARK: - Persistence

    mutating func save(supabaseUrl url: String, anonKey key: String, useMockRFID: Bool) {
        supabaseUrl = url
        supabaseAnonKey = key
        self.useMockRFID = useMockRFID
    }

    func clearSupabaseConfig() {
        UserDefaults.standard.removeObject(forKey: Keys.supabaseUrl)
        UserDefaults.standard.removeObject(forKey: Keys.supabaseAnonKey)
    }
}
