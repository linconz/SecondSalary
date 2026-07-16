import Foundation
@testable import SecondSalary

@MainActor
final class InMemoryPreferencesStore: PreferencesStoring {
    var refreshInterval: RefreshInterval = .oneSecond
    var showsEarningsInMenuBar = true
    var launchAtLoginRequested = false
}
