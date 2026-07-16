import AppKit
import XCTest
@testable import SecondSalary

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testTitleAndImageUseStatusBarAlignmentMetrics() throws {
        let model = AppModel(
            secureStore: InMemorySecureStateStore(),
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            observesSystemEvents: false
        )
        let controller = StatusItemController(
            model: model,
            openSettings: {},
            openAbout: {}
        )
        defer { controller.invalidate() }

        XCTAssertEqual(controller.displayedTitleBaselineOffset, -1)
        let imageSize = try XCTUnwrap(controller.displayedImageSize)
        XCTAssertEqual(imageSize.width, 18)
        XCTAssertEqual(imageSize.height, 12)
        let alignmentRect = try XCTUnwrap(controller.displayedImageAlignmentRect)
        XCTAssertEqual(alignmentRect.origin.y, 3)
    }

    func testChangedAmountTurnsGreenThenReturnsToSystemColor() async throws {
        let start = Date.now
        let model = AppModel(
            secureStore: InMemorySecureStateStore(),
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            now: start,
            observesSystemEvents: false
        )
        let controller = StatusItemController(
            model: model,
            openSettings: {},
            openAbout: {}
        )
        defer { controller.invalidate() }

        XCTAssertTrue(model.saveSettings(
            CompensationSettings(
                monthlySalary: 20_000,
                monthlyWorkdays: 21,
                workStartMinute: 9 * 60,
                workEndMinute: 17 * 60,
                currency: .cny
            ),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))
        model.toggleSession(at: start)
        model.refreshDisplay(at: start.addingTimeInterval(1))

        let highlightedColor = try XCTUnwrap(controller.displayedTitleColor)
        XCTAssertTrue(highlightedColor.isEqual(NSColor.systemGreen))

        try await Task.sleep(for: .milliseconds(850))
        XCTAssertNil(controller.displayedTitleColor)
    }

    func testDisablingMenuBarDisplayLeavesOnlyTheIcon() {
        let model = AppModel(
            secureStore: InMemorySecureStateStore(),
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            observesSystemEvents: false
        )
        let controller = StatusItemController(
            model: model,
            openSettings: {},
            openAbout: {}
        )
        defer { controller.invalidate() }

        XCTAssertFalse(controller.displayedTitle.isEmpty)
        XCTAssertEqual(controller.displayedImagePosition, .imageLeading)

        XCTAssertTrue(model.saveSettings(
            CompensationSettings(
                monthlySalary: 20_000,
                monthlyWorkdays: 21,
                workStartMinute: 9 * 60,
                workEndMinute: 17 * 60,
                currency: .cny
            ),
            refreshInterval: .oneSecond,
            showsEarningsInMenuBar: false,
            launchAtLogin: false
        ))

        XCTAssertTrue(controller.displayedTitle.isEmpty)
        XCTAssertEqual(controller.displayedImagePosition, .imageOnly)
    }
}
