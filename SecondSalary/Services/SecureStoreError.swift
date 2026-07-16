import Foundation

enum SecureStoreError: LocalizedError {
    case unexpectedData
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedData:
            "钥匙串中的数据无法读取，请重置应用数据后重试。"
        case .keychain(let status):
            "钥匙串操作失败，错误代码：\(status)。"
        }
    }
}
