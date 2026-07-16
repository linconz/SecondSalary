import Foundation

@MainActor
protocol PreferencesStoring {
    var refreshInterval: RefreshInterval { get set }
    var showsEarningsInMenuBar: Bool { get set }
    var launchAtLoginRequested: Bool { get set }
}
