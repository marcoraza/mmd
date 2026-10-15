import Foundation
import Security

/// Guarda pequenos segredos no Keychain do device.
///
/// O app legado deixava o operador colar um JWT em Ajustes e guardava em
/// `UserDefaults`: sem login, sem refresh e com o token legível por backup.
/// Aqui o token vive no Keychain, com `kSecAttrAccessibleAfterFirstUnlock` —
/// o app precisa ler credencial em background (reconexão do leitor, retry de
/// requisição), mas nada é lido antes do primeiro desbloqueio do aparelho.
struct KeychainStore {

    enum Key: String, CaseIterable {
        case accessToken = "eventpro.auth.access_token"
        case refreshToken = "eventpro.auth.refresh_token"
        case expiresAt = "eventpro.auth.expires_at"
        case userId = "eventpro.auth.user_id"
        case userEmail = "eventpro.auth.user_email"
    }

    enum KeychainError: LocalizedError, Equatable {
        case unexpectedStatus(OSStatus)
        case invalidData

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                return "Falha no Keychain (código \(status))."
            case .invalidData:
                return "Dado inválido no Keychain."
            }
        }
    }

    /// Serviço do Keychain. Isola o EventPro de qualquer resquício do app antigo.
    private let service: String

    init(service: String = "com.emdash.eventpro.auth") {
        self.service = service
    }

    // MARK: - Read / write

    func string(for key: Key) -> String? {
        guard let data = data(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func data(for key: Key) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    func set(_ value: String?, for key: Key) -> Result<Void, KeychainError> {
        guard let value else {
            return remove(key)
        }
        guard let data = value.data(using: .utf8) else {
            return .failure(.invalidData)
        }
        return set(data, for: key)
    }

    @discardableResult
    func set(_ data: Data, for key: Key) -> Result<Void, KeychainError> {
        let query = baseQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return .success(())
        }
        if updateStatus != errSecItemNotFound {
            return .failure(.unexpectedStatus(updateStatus))
        }

        var insert = query
        insert.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            return .failure(.unexpectedStatus(addStatus))
        }
        return .success(())
    }

    @discardableResult
    func remove(_ key: Key) -> Result<Void, KeychainError> {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return .failure(.unexpectedStatus(status))
        }
        return .success(())
    }

    func removeAll() {
        for key in Key.allCases {
            _ = remove(key)
        }
    }

    // MARK: - Private

    private func baseQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}
