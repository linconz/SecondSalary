import SwiftUI

struct SystemTimeField: NSViewRepresentable {
    @Binding var selection: Date
    let accessibilityLabel: String

    func makeCoordinator() -> SystemTimeFieldCoordinator {
        SystemTimeFieldCoordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        picker.datePickerMode = .single
        picker.calendar = .autoupdatingCurrent
        picker.locale = .autoupdatingCurrent
        picker.isBezeled = true
        picker.isBordered = true
        picker.dateValue = selection
        picker.target = context.coordinator
        picker.action = #selector(SystemTimeFieldCoordinator.selectionChanged(_:))
        picker.setAccessibilityLabel(accessibilityLabel)
        return picker
    }

    func updateNSView(_ picker: NSDatePicker, context: Context) {
        context.coordinator.selection = $selection
        picker.setAccessibilityLabel(accessibilityLabel)
        if picker.dateValue != selection {
            picker.dateValue = selection
        }
    }
}
