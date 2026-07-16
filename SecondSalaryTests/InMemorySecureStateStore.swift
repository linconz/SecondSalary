import Foundation
@testable import SecondSalary

@MainActor
final class InMemorySecureStateStore: SecureStateStoring {
    var state: SecureState?
    var error: Error?

    func load() throws -> SecureState? {
        if let error { throw error }
        return state
    }

    func save(_ state: SecureState) throws {
        if let error { throw error }
        self.state = state
    }

    func reset() throws {
        if let error { throw error }
        state = nil
    }
}
