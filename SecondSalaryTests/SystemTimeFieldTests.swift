import AppKit
import SwiftUI
import XCTest
@testable import SecondSalary

@MainActor
final class SystemTimeFieldTests: XCTestCase {
    func testUsesSystemSegmentedTimeEditorAndUpdatesBinding() throws {
        var selection = Date.now
        let binding = Binding(
            get: { selection },
            set: { selection = $0 }
        )
        let hostingView = NSHostingView(
            rootView: SystemTimeField(
                selection: binding,
                accessibilityLabel: "上班时间"
            )
        )
        let window = NSWindow(contentViewController: NSViewController())
        window.contentView = hostingView
        window.setContentSize(NSSize(width: 160, height: 40))
        hostingView.layoutSubtreeIfNeeded()

        let picker = try XCTUnwrap(firstDatePicker(in: hostingView))
        XCTAssertEqual(picker.datePickerStyle, .textFieldAndStepper)
        XCTAssertEqual(picker.datePickerElements, .hourMinute)
        XCTAssertFalse(picker.isBezeled)
        XCTAssertFalse(picker.isBordered)
        XCTAssertNotNil(picker.target)
        XCTAssertNotNil(picker.action)

        let updatedDate = selection.addingTimeInterval(3_600)
        picker.dateValue = updatedDate
        picker.sendAction(picker.action, to: picker.target)

        XCTAssertEqual(selection, updatedDate)
    }

    private func firstDatePicker(in view: NSView) -> NSDatePicker? {
        if let picker = view as? NSDatePicker {
            return picker
        }
        for subview in view.subviews {
            if let picker = firstDatePicker(in: subview) {
                return picker
            }
        }
        return nil
    }
}
