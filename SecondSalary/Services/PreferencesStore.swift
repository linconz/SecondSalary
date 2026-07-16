import Foundation

@MainActor
final class PreferencesStore: PreferencesStoring {
    private let defaults: UserDefaults
    private let refreshIntervalKey = "refreshInterval"
    private let launchAtLoginKey = "launchAtLoginRequested"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var refreshInterval: RefreshInterval {
        get {
            let storedValue = defaults.integer(forKey: refreshIntervalKey)
            return RefreshInterval(rawValue: storedValue) ?? .oneSecond
        }
        set {
            defaults.set(newValue.rawValue, forKey: refreshIntervalKey)
        }
    }

    var launchAtLoginRequested: Bool {
        get { defaults.bool(forKey: launchAtLoginKey) }
        set { defaults.set(newValue, forKey: launchAtLoginKey) }
    }
}
