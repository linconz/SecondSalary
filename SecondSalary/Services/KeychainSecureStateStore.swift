import Foundation
import Security

@MainActor
final class KeychainSecureStateStore: SecureStateStoring {
    private let service = "com.zhangyilin.SecondSalary"
    private let account = "secure-state"

    func load() throws -> SecureState? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw SecureStoreError.keychain(status)
        }
        guard let data = result as? Data else {
            throw SecureStoreError.unexpectedData
        }

        do {
            return try decoder.decode(SecureState.self, from: data)
        } catch {
            throw SecureStoreError.unexpectedData
        }
    }

    func save(_ state: SecureState) throws {
        let data = try encoder.encode(state)
        let attributes = [kSecValueData: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw SecureStoreError.keychain(updateStatus)
        }

        var newItem = baseQuery
        newItem[kSecValueData] = data
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SecureStoreError.keychain(addStatus)
        }
    }

    func reset() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStoreError.keychain(status)
        }
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
