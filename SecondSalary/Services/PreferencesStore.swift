import Foundation

@MainActor
final class PreferencesStore: PreferencesStoring {
    private let defaults: UserDefaults
    private let refreshIntervalKey = "refreshInterval"
    private let showsEarningsInMenuBarKey = "showsEarningsInMenuBar"
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

    var showsEarningsInMenuBar: Bool {
        get {
            guard defaults.object(forKey: showsEarningsInMenuBarKey) != nil else {
                return true
            }
            return defaults.bool(forKey: showsEarningsInMenuBarKey)
        }
        set {
            defaults.set(newValue, forKey: showsEarningsInMenuBarKey)
        }
    }

    var launchAtLoginRequested: Bool {
        get { defaults.bool(forKey: launchAtLoginKey) }
        set { defaults.set(newValue, forKey: launchAtLoginKey) }
    }
}
