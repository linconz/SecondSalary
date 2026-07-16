import Foundation

enum TestServiceError: LocalizedError {
    case expectedFailure

    var errorDescription: String? { "预期的测试错误" }
}
