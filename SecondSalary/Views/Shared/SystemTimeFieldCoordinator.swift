import SwiftUI

@MainActor
final class SystemTimeFieldCoordinator: NSObject {
    var selection: Binding<Date>

    init(selection: Binding<Date>) {
        self.selection = selection
    }

    @objc func selectionChanged(_ sender: NSDatePicker) {
        selection.wrappedValue = sender.dateValue
    }
}
