import XCTest
@testable import SecondSalary

@MainActor
final class PreferencesStoreTests: XCTestCase {
    func testMenuBarDisplayDefaultsToEnabledAndPersistsChanges() throws {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = PreferencesStore(defaults: defaults)

        XCTAssertTrue(store.showsEarningsInMenuBar)

        store.showsEarningsInMenuBar = false

        XCTAssertFalse(store.showsEarningsInMenuBar)
    }
}
