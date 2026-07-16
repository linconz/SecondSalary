import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    private var statusItemController: StatusItemController?
    private lazy var settingsWindowController = SettingsWindowController(model: model)
    private let aboutWindowController = AboutWindowController()
    private var initialSettingsTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(
            model: model,
            openSettings: { [weak self] in self?.openSettings() },
            openAbout: { [weak self] in self?.openAbout() }
        )

        initialSettingsTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, model.takeInitialSettingsRequest() else { return }
            openSettings()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func openSettings() {
        activateApplication()
        settingsWindowController.show()
    }

    private func openAbout() {
        activateApplication()
        aboutWindowController.show()
    }

    private func activateApplication() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
