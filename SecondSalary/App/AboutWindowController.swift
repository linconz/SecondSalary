import AppKit
import SwiftUI

@MainActor
final class AboutWindowController {
    private var windowController: NSWindowController?

    func show() {
        let controller = windowController ?? makeWindowController()
        windowController = controller
        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindowController() -> NSWindowController {
        let hostingController = NSHostingController(rootView: AboutView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "关于 SecondSalary"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 360, height: 360))
        window.isReleasedWhenClosed = false
        return NSWindowController(window: window)
    }
}
