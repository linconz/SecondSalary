import Foundation
@testable import SecondSalary

@MainActor
final class InMemoryPreferencesStore: PreferencesStoring {
    var refreshInterval: RefreshInterval = .oneSecond
    var launchAtLoginRequested = false
}
