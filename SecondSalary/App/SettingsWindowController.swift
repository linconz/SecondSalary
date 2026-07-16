import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private var windowController: NSWindowController?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let controller = windowController ?? makeWindowController()
        windowController = controller
        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindowController() -> NSWindowController {
        let settingsView = SettingsView(
            model: model,
            closeAction: { [weak self] in self?.windowController?.close() }
        )
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SecondSalary 设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 460, height: 500))
        window.isReleasedWhenClosed = false
        return NSWindowController(window: window)
    }
}
