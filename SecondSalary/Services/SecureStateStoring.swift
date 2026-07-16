import Foundation

@MainActor
protocol SecureStateStoring {
    func load() throws -> SecureState?
    func save(_ state: SecureState) throws
    func reset() throws
}
