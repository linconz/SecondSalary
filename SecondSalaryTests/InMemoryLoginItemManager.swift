import Foundation
@testable import SecondSalary

@MainActor
final class InMemoryLoginItemManager: LoginItemManaging {
    var isEnabled = false
    var shouldFail = false

    func setEnabled(_ enabled: Bool) throws {
        if shouldFail {
            throw TestServiceError.expectedFailure
        }
        isEnabled = enabled
    }
}
