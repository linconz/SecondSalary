import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private static let statusImagePointSize = 12.0
    private static let statusImageVerticalOffset = 3.0
    private static let titleBaselineOffset = -1.0

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let emotionalPromptPopover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    private var highlightResetTask: Task<Void, Never>?
    private var lastDisplayedAmount: String
    private var isHighlighted = false

    init(
        model: AppModel,
        openSettings: @escaping () -> Void,
        openAbout: @escaping () -> Void
    ) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        lastDisplayedAmount = model.formattedTodayEarnings(at: model.displayDate)
        super.init()

        configureStatusButton()
        configurePopover(openSettings: openSettings, openAbout: openAbout)
        configureEmotionalPromptPopover()
        observeModel()
    }

    var displayedTitleColor: NSColor? {
        statusItem.button?.attributedTitle.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor
    }

    var displayedTitle: String {
        statusItem.button?.attributedTitle.string ?? ""
    }

    var displayedImagePosition: NSControl.ImagePosition? {
        statusItem.button?.imagePosition
    }

    var displayedTitleBaselineOffset: Double? {
        statusItem.button?.attributedTitle.attribute(
            .baselineOffset,
            at: 0,
            effectiveRange: nil
        ) as? Double
    }

    var displayedImageSize: NSSize? {
        statusItem.button?.image?.size
    }

    var displayedImageAlignmentRect: NSRect? {
        statusItem.button?.image?.alignmentRect
    }

    func invalidate() {
        refreshTask?.cancel()
        highlightResetTask?.cancel()
        cancellables.removeAll()
        emotionalPromptPopover.close()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }

        let symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: Self.statusImagePointSize,
            weight: .regular
        )
        let image = NSImage(
            systemSymbolName: "banknote",
            accessibilityDescription: "工资计数器"
        )?.withSymbolConfiguration(symbolConfiguration)
        if let image {
            image.alignmentRect = NSRect(
                x: 0,
                y: Self.statusImageVerticalOffset,
                width: image.size.width,
                height: image.size.height
            )
        }
        image?.isTemplate = true
        button.image = image
        button.imageScaling = .scaleNone
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "SecondSalary 今日累计工资"
        applyTitle(lastDisplayedAmount, highlighted: false)
    }

    private func configurePopover(
        openSettings: @escaping () -> Void,
        openAbout: @escaping () -> Void
    ) {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: AppDesign.popoverWidth, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(
                model: model,
                openSettingsAction: openSettings,
                openAboutAction: openAbout
            )
        )
    }

    private func configureEmotionalPromptPopover() {
        emotionalPromptPopover.behavior = .applicationDefined
        emotionalPromptPopover.animates = true
        emotionalPromptPopover.contentSize = NSSize(
            width: AppDesign.emotionalPromptWidth,
            height: AppDesign.emotionalPromptHeight
        )
    }

    private func observeModel() {
        model.$displayDate
            .dropFirst()
            .sink { [weak self] date in
                self?.updateDisplayedAmount(at: date)
            }
            .store(in: &cancellables)

        model.$refreshInterval
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.restartRefreshLoop()
            }
            .store(in: &cancellables)

        model.$showsEarningsInMenuBar
            .removeDuplicates()
            .sink { [weak self] showsEarnings in
                guard let self else { return }
                if !showsEarnings {
                    highlightResetTask?.cancel()
                    isHighlighted = false
                }
                applyTitle(lastDisplayedAmount, highlighted: isHighlighted)
            }
            .store(in: &cancellables)

        model.$emotionalPrompt
            .removeDuplicates()
            .sink { [weak self] prompt in
                self?.updateEmotionalPrompt(prompt)
            }
            .store(in: &cancellables)
    }

    private func restartRefreshLoop() {
        refreshTask?.cancel()
        let interval = model.refreshInterval.timeInterval
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
                self?.model.refreshDisplay(at: .now)
            }
        }
    }

    private func updateDisplayedAmount(at date: Date) {
        let amount = model.formattedTodayEarnings(at: date)
        guard amount != lastDisplayedAmount else {
            if !isHighlighted {
                applyTitle(amount, highlighted: false)
            }
            return
        }

        lastDisplayedAmount = amount
        isHighlighted = true
        applyTitle(amount, highlighted: true)
        scheduleHighlightReset(for: amount)
    }

    private func scheduleHighlightReset(for amount: String) {
        highlightResetTask?.cancel()
        highlightResetTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(800))
            } catch {
                return
            }
            guard let self, lastDisplayedAmount == amount else { return }
            isHighlighted = false
            applyTitle(amount, highlighted: false)
        }
    }

    private func applyTitle(_ title: String, highlighted: Bool) {
        guard let button = statusItem.button else { return }

        guard model.showsEarningsInMenuBar else {
            button.attributedTitle = NSAttributedString()
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel("SecondSalary 工资计数器")
            return
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0),
            .baselineOffset: Self.titleBaselineOffset
        ]
        if highlighted {
            attributes[.foregroundColor] = NSColor.systemGreen
        }
        button.imagePosition = .imageLeading
        button.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        button.setAccessibilityLabel("今日累计工资，\(title)")
    }

    private func updateEmotionalPrompt(_ prompt: EmotionalPromptPresentation?) {
        guard let prompt else {
            emotionalPromptPopover.performClose(nil)
            return
        }
        guard !popover.isShown, let button = statusItem.button else { return }

        emotionalPromptPopover.contentViewController = NSHostingController(
            rootView: EmotionalPromptBubbleView(message: prompt.message)
        )
        emotionalPromptPopover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            emotionalPromptPopover.performClose(nil)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
