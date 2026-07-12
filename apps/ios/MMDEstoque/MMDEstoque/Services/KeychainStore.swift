import Foundation
import Security

// MARK: - SessionStoring

/// Persistência mínima de sessão (Keychain em produção, memória nos testes).
protocol SessionStoring: Sendable {
    func load() throws -> Data?
    func save(_ data: Data) throws
    func delete() throws
}

// MARK: - KeychainStore

/// Helper mínimo de Keychain. Um item por `service` (account fixo "session").
struct KeychainStore: SessionStoring {
    let service: String

    private let account = "session"

    func load() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func save(_ data: Data) throws {
        // Remove item antigo pra evitar errSecDuplicateItem.
        try? delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

// MARK: - InMemorySessionStore (testes)

final class InMemorySessionStore: SessionStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    func load() throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return data
    }

    func save(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        self.data = data
    }

    func delete() throws {
        lock.lock()
        defer { lock.unlock() }
        data = nil
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain falhou com status \(status)."
        }
    }
}
