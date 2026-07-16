import Foundation

@MainActor
protocol PreferencesStoring {
    var refreshInterval: RefreshInterval { get set }
    var launchAtLoginRequested: Bool { get set }
}
