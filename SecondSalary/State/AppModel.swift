import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: NSObject, ObservableObject {
    @Published private(set) var settings: CompensationSettings?
    @Published private(set) var dailyRecord: DailyWorkRecord?
    @Published private(set) var refreshInterval: RefreshInterval
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var displayDate: Date
    @Published private(set) var emotionalPrompt: EmotionalPromptPresentation?
    @Published private(set) var statusHeaderMessage: String?
    @Published var isShowingError = false
    @Published private(set) var errorMessage = ""

    private let secureStore: any SecureStateStoring
    private var preferences: any PreferencesStoring
    private let loginItemManager: any LoginItemManaging
    private let calendar: Calendar
    private let emotionalPromptSchedule: EmotionalPromptSchedule
    private let workStartedPromptDelay: Duration
    private let emotionalPromptDisplayDuration: Duration
    private var dayStart: Date
    private var hasRequestedInitialSettings = false
    private var scheduledPromptTask: Task<Void, Never>?
    private var workStartedPromptTask: Task<Void, Never>?
    private var promptDismissalTask: Task<Void, Never>?
    private var queuedEmotionalPrompts: [EmotionalPromptPresentation] = []

    init(
        secureStore: any SecureStateStoring = KeychainSecureStateStore(),
        preferences: any PreferencesStoring = PreferencesStore(),
        loginItemManager: any LoginItemManaging = LoginItemManager(),
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = .now,
        observesSystemEvents: Bool = true,
        workStartedPromptDelay: Duration = .seconds(5),
        emotionalPromptDisplayDuration: Duration = .seconds(5)
    ) {
        self.secureStore = secureStore
        self.preferences = preferences
        self.loginItemManager = loginItemManager
        self.calendar = calendar
        emotionalPromptSchedule = EmotionalPromptSchedule(calendar: calendar)
        self.workStartedPromptDelay = workStartedPromptDelay
        self.emotionalPromptDisplayDuration = emotionalPromptDisplayDuration

        let today = calendar.startOfDay(for: now)
        var loadError: Error?
        let loadedState: SecureState?
        do {
            loadedState = try secureStore.load()
        } catch {
            loadedState = nil
            loadError = error
        }

        settings = loadedState?.settings
        dailyRecord = loadedState?.dailyRecord
        dayStart = loadedState?.dayStart ?? today
        refreshInterval = preferences.refreshInterval
        launchAtLogin = loginItemManager.isEnabled
        displayDate = now
        emotionalPrompt = nil
        statusHeaderMessage = nil

        super.init()

        if observesSystemEvents {
            registerForSystemEvents()
        }
        if let loadError {
            present(error: loadError)
        }
        handleTick(at: now)
        restartEmotionalPromptSchedule(after: now, includingCurrentMinute: true)
    }

    deinit {
        scheduledPromptTask?.cancel()
        workStartedPromptTask?.cancel()
        promptDismissalTask?.cancel()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    var displayCurrency: CurrencyOption {
        settings?.currency ?? dailyRecord?.currency ?? .cny
    }

    var hasValidSettings: Bool {
        settings?.isValid == true
    }

    var isWorking: Bool {
        dailyRecord?.isActive == true
    }

    var hasTodayRecord: Bool {
        dailyRecord != nil
    }

    var currentRate: PayRateSnapshot? {
        dailyRecord?.activeRate ?? settings.flatMap(EarningsCalculator.rate)
    }

    func takeInitialSettingsRequest() -> Bool {
        guard settings == nil, !hasRequestedInitialSettings else { return false }
        hasRequestedInitialSettings = true
        return true
    }

    @discardableResult
    func handleTick(at now: Date) -> Bool {
        let didStopAtScheduledWorkEnd = enforceScheduledWorkEnd(at: now)
        let newDayStart = calendar.startOfDay(for: now)
        guard newDayStart != dayStart else { return didStopAtScheduledWorkEnd }

        workStartedPromptTask?.cancel()
        clearEmotionalPrompts()
        let adjustedRecord = recordForDay(startingAt: newDayStart)
        dayStart = newDayStart
        dailyRecord = adjustedRecord
        persistCurrentState()
        displayDate = now
        restartEmotionalPromptSchedule(after: now, includingCurrentMinute: true)
        return didStopAtScheduledWorkEnd
    }

    func refreshDisplay(at now: Date) {
        handleTick(at: now)
        displayDate = now
    }

    func recordForDisplay(at now: Date) -> DailyWorkRecord? {
        let today = calendar.startOfDay(for: now)
        if today == dayStart {
            return dailyRecord
        }
        return recordForDay(startingAt: today)
    }

    func todayDuration(at now: Date) -> TimeInterval {
        recordForDisplay(at: now)?.duration(at: now) ?? 0
    }

    func todayEarnings(at now: Date) -> Decimal {
        recordForDisplay(at: now)?.earnings(at: now) ?? .zero
    }

    func formattedTodayEarnings(at now: Date) -> String {
        displayCurrency.formatted(todayEarnings(at: now))
    }

    func formattedCurrentRate() -> String {
        guard let currentRate else {
            return displayCurrency.formattedRate(.zero)
        }
        return currentRate.currency.formattedRate(currentRate.perSecond)
    }

    func statusHeaderMessage(at now: Date) -> String? {
        if isWaitingForWork(at: now) {
            return EmotionalPrompt.waitingForWork.message(
                todayEarnings: formattedTodayEarnings(at: now)
            )
        }
        if let contextualPrompt = contextualWorkEndPrompt(at: now) {
            return contextualPrompt.message(
                todayEarnings: formattedTodayEarnings(at: now)
            )
        }
        return statusHeaderMessage
    }

    private func isWaitingForWork(at now: Date) -> Bool {
        guard let activeSegment = dailyRecord?.segments.last(where: \.isActive) else {
            return false
        }
        return activeSegment.startedAt > now
    }

    func toggleSession(at now: Date = .now) {
        guard !handleTick(at: now) else { return }
        if isWorking {
            stopCurrentSession(reason: .manual, at: now)
        } else {
            startSession(at: now)
        }
    }

    func saveSettings(
        _ newSettings: CompensationSettings,
        refreshInterval newRefreshInterval: RefreshInterval,
        launchAtLogin requestedLaunchAtLogin: Bool
    ) -> Bool {
        handleTick(at: .now)

        if let validationMessage = newSettings.validationMessage {
            present(message: validationMessage)
            return false
        }
        if hasTodayRecord,
           let existingCurrency = settings?.currency,
           existingCurrency != newSettings.currency {
            present(message: "当天已有记录时不能更改币种。请清空今日记录或次日再修改。")
            return false
        }

        let previousSettings = settings
        settings = newSettings
        guard persistCurrentState() else {
            settings = previousSettings
            return false
        }

        refreshInterval = newRefreshInterval
        preferences.refreshInterval = newRefreshInterval
        updateLaunchAtLogin(requestedLaunchAtLogin)
        refreshDisplay(at: .now)
        restartEmotionalPromptSchedule(after: .now, includingCurrentMinute: true)
        return true
    }

    func clearToday() {
        let previousRecord = dailyRecord
        dailyRecord = nil
        guard persistCurrentState() else {
            dailyRecord = previousRecord
            return
        }
        refreshDisplay(at: .now)
    }

    func resetAllData() {
        do {
            try secureStore.reset()
        } catch {
            present(error: error)
            return
        }

        settings = nil
        dailyRecord = nil
        dayStart = calendar.startOfDay(for: .now)
        refreshInterval = .oneSecond
        displayDate = .now
        preferences.refreshInterval = .oneSecond
        hasRequestedInitialSettings = false
        workStartedPromptTask?.cancel()
        clearEmotionalPrompts()
        restartEmotionalPromptSchedule(after: .now)

        if launchAtLogin {
            do {
                try loginItemManager.setEnabled(false)
                launchAtLogin = loginItemManager.isEnabled
                preferences.launchAtLoginRequested = launchAtLogin
            } catch {
                present(message: "本机数据已删除，但无法关闭登录时启动：\(error.localizedDescription)")
            }
        } else {
            preferences.launchAtLoginRequested = false
        }
    }

    func handleSystemSleep(at now: Date = .now) {
        stopCurrentSession(reason: .sleep, at: now)
        scheduledPromptTask?.cancel()
    }

    func handleSystemPowerOff(at now: Date = .now) {
        stopCurrentSession(reason: .powerOff, at: now)
    }

    func quitApplication() {
        stopCurrentSession(reason: .quit, at: .now)
        NSApplication.shared.terminate(nil)
    }

    private func startSession(at now: Date) {
        guard let settings else {
            present(message: "请先完成工资设置。")
            return
        }
        guard let rate = EarningsCalculator.rate(for: settings) else {
            present(message: settings.validationMessage ?? "工资设置无效。")
            return
        }

        let isFirstSessionToday = dailyRecord == nil
        let startedAt = segmentStartDate(for: settings, at: now)
        let previousRecord = dailyRecord
        if dailyRecord == nil {
            dailyRecord = DailyWorkRecord()
        }
        dailyRecord?.segments.append(WorkSegment(startedAt: startedAt, rate: rate))
        if !persistCurrentState() {
            dailyRecord = previousRecord
        } else {
            refreshDisplay(at: now)
            if isFirstSessionToday {
                scheduleWorkStartedPrompt()
            }
        }
    }

    private func segmentStartDate(
        for settings: CompensationSettings,
        at now: Date
    ) -> Date {
        guard let scheduledStart = scheduledWorkStart(
            containingOrFollowing: now,
            settings: settings
        ) else {
            return now
        }

        // 工作时段外开始时，使用下一次计划上班时间作为实际计薪起点。
        guard scheduledStart <= now else { return scheduledStart }
        guard dailyRecord == nil else { return now }
        return max(scheduledStart, dayStart)
    }

    private func scheduledWorkStart(
        containingOrFollowing now: Date,
        settings: CompensationSettings
    ) -> Date? {
        let today = calendar.startOfDay(for: now)
        guard let todayStart = calendar.date(
            bySettingHour: settings.workStartMinute / 60,
            minute: settings.workStartMinute % 60,
            second: 0,
            of: today
        ), let todayEnd = calendar.date(
            bySettingHour: settings.workEndMinute / 60,
            minute: settings.workEndMinute % 60,
            second: 0,
            of: today
        ) else {
            return nil
        }

        let crossesMidnight = settings.workEndMinute < settings.workStartMinute
        if crossesMidnight {
            if now < todayEnd {
                guard let previousDay = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: today
                ) else {
                    return nil
                }
                return calendar.date(
                    bySettingHour: settings.workStartMinute / 60,
                    minute: settings.workStartMinute % 60,
                    second: 0,
                    of: previousDay
                )
            }
            return todayStart
        }

        guard now >= todayEnd else { return todayStart }
        guard let nextDay = calendar.date(
            byAdding: .day,
            value: 1,
            to: today
        ) else {
            return nil
        }
        return calendar.date(
            bySettingHour: settings.workStartMinute / 60,
            minute: settings.workStartMinute % 60,
            second: 0,
            of: nextDay
        )
    }

    private func stopCurrentSession(reason: StopReason, at now: Date) {
        handleTick(at: now)
        if endActiveSegment(reason: reason, at: now) {
            refreshDisplay(at: now)
        }
    }

    @discardableResult
    private func endActiveSegment(reason: StopReason, at endDate: Date) -> Bool {
        guard var record = dailyRecord,
              let index = record.segments.lastIndex(where: \.isActive) else { return false }

        let previousRecord = dailyRecord
        var segment = record.segments[index]
        segment.endedAt = max(endDate, segment.startedAt)
        segment.stopReason = reason
        record.segments[index] = segment
        dailyRecord = record
        guard persistCurrentState() else {
            dailyRecord = previousRecord
            return false
        }

        workStartedPromptTask?.cancel()
        return true
    }

    @discardableResult
    private func enforceScheduledWorkEnd(at now: Date) -> Bool {
        guard let settings,
              let activeSegment = dailyRecord?.segments.last(where: \.isActive),
              let scheduledEnd = scheduledWorkEnd(
                for: activeSegment.startedAt,
                settings: settings
              ),
              scheduledEnd <= now else {
            return false
        }

        guard endActiveSegment(
            reason: .scheduledWorkEnd,
            at: scheduledEnd
        ) else {
            return false
        }
        displayDate = now
        return true
    }

    private func scheduledWorkEnd(
        for segmentStart: Date,
        settings: CompensationSettings
    ) -> Date? {
        let segmentDay = calendar.startOfDay(for: segmentStart)
        guard let workEndOnSegmentDay = calendar.date(
            bySettingHour: settings.workEndMinute / 60,
            minute: settings.workEndMinute % 60,
            second: 0,
            of: segmentDay
        ) else {
            return nil
        }

        let segmentComponents = calendar.dateComponents(
            [.hour, .minute],
            from: segmentStart
        )
        let segmentMinute = (segmentComponents.hour ?? 0) * 60
            + (segmentComponents.minute ?? 0)
        let crossesMidnight = settings.workEndMinute < settings.workStartMinute
        if crossesMidnight, segmentMinute >= settings.workStartMinute {
            return calendar.date(byAdding: .day, value: 1, to: workEndOnSegmentDay)
        }
        return workEndOnSegmentDay
    }

    func presentEmotionalPrompts(
        _ prompts: [EmotionalPrompt],
        at date: Date
    ) {
        let earnings = formattedTodayEarnings(at: date)
        queuedEmotionalPrompts.append(contentsOf: prompts.map { prompt in
            EmotionalPromptPresentation(
                prompt: prompt,
                message: prompt.message(todayEarnings: earnings),
                triggeredAt: date
            )
        })
        presentNextEmotionalPromptIfNeeded()
    }

    private func scheduleWorkStartedPrompt() {
        workStartedPromptTask?.cancel()
        let delay = workStartedPromptDelay
        workStartedPromptTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self, isWorking else { return }
            presentEmotionalPrompts([.workStarted], at: .now)
        }
    }

    private func restartEmotionalPromptSchedule(
        after date: Date,
        includingCurrentMinute: Bool = false
    ) {
        scheduledPromptTask?.cancel()
        guard let settings, settings.isValid,
              let occurrence = emotionalPromptSchedule.nextOccurrence(
                after: date,
                includingCurrentMinute: includingCurrentMinute,
                settings: settings
              ) else {
            return
        }

        let delay = max(occurrence.date.timeIntervalSinceNow, 0)
        scheduledPromptTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard let self else { return }
            let triggeredAt = Date.now
            if occurrence.prompts.contains(.afterWork) {
                enforceScheduledWorkEnd(at: occurrence.date)
            }
            presentEmotionalPrompts(occurrence.prompts, at: triggeredAt)
            restartEmotionalPromptSchedule(after: triggeredAt)
        }
    }

    private func presentNextEmotionalPromptIfNeeded() {
        guard emotionalPrompt == nil, !queuedEmotionalPrompts.isEmpty else { return }

        let nextPrompt = queuedEmotionalPrompts.removeFirst()
        emotionalPrompt = nextPrompt
        statusHeaderMessage = nextPrompt.message
        let displayDuration = emotionalPromptDisplayDuration
        promptDismissalTask?.cancel()
        promptDismissalTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: displayDuration)
            } catch {
                return
            }
            guard let self, emotionalPrompt?.id == nextPrompt.id else { return }
            emotionalPrompt = nil
            presentNextEmotionalPromptIfNeeded()
        }
    }

    private func clearEmotionalPrompts() {
        promptDismissalTask?.cancel()
        queuedEmotionalPrompts.removeAll()
        emotionalPrompt = nil
        statusHeaderMessage = nil
    }

    private func contextualWorkEndPrompt(at now: Date) -> EmotionalPrompt? {
        guard let settings else { return nil }

        let today = calendar.startOfDay(for: now)
        guard let todayWorkEnd = calendar.date(
            bySettingHour: settings.workEndMinute / 60,
            minute: settings.workEndMinute % 60,
            second: 0,
            of: today
        ) else {
            return nil
        }

        let previousDay = calendar.date(byAdding: .day, value: -1, to: today)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: today)
        let previousWorkEnd = previousDay.flatMap { day in
            calendar.date(
                bySettingHour: settings.workEndMinute / 60,
                minute: settings.workEndMinute % 60,
                second: 0,
                of: day
            )
        }
        let nextWorkEnd = nextDay.flatMap { day in
            calendar.date(
                bySettingHour: settings.workEndMinute / 60,
                minute: settings.workEndMinute % 60,
                second: 0,
                of: day
            )
        }

        let mostRecentWorkEnd = todayWorkEnd <= now ? todayWorkEnd : previousWorkEnd
        if let mostRecentWorkEnd {
            let elapsedTime = now.timeIntervalSince(mostRecentWorkEnd)
            let workEndDay = calendar.startOfDay(for: mostRecentWorkEnd)
            if let workStartOnEndDay = calendar.date(
                bySettingHour: settings.workStartMinute / 60,
                minute: settings.workStartMinute % 60,
                second: 0,
                of: workEndDay
            ) {
                let nextWorkStart = workStartOnEndDay > mostRecentWorkEnd
                    ? workStartOnEndDay
                    : calendar.date(byAdding: .day, value: 1, to: workStartOnEndDay)

                if let nextWorkStart, now < nextWorkStart {
                    if elapsedTime >= 60 * 60 {
                        return .workStarted
                    }
                    if elapsedTime >= 5 * 60 {
                        return .fiveMinutesAfterWork
                    }
                    if elapsedTime >= 0 {
                        return .afterWork
                    }
                }
            }
        }

        let upcomingWorkEnd = todayWorkEnd > now ? todayWorkEnd : nextWorkEnd
        guard let upcomingWorkEnd else { return nil }
        let remainingTime = upcomingWorkEnd.timeIntervalSince(now)
        if remainingTime > 0, remainingTime <= 30 * 60 {
            return .almostOffWork
        }
        return nil
    }

    private func updateLaunchAtLogin(_ requestedValue: Bool) {
        guard requestedValue != launchAtLogin else {
            preferences.launchAtLoginRequested = requestedValue
            return
        }

        do {
            try loginItemManager.setEnabled(requestedValue)
            launchAtLogin = loginItemManager.isEnabled
            preferences.launchAtLoginRequested = launchAtLogin
            if launchAtLogin != requestedValue {
                present(message: "系统尚未批准登录时启动，请在“系统设置 > 通用 > 登录项”中检查授权。")
            }
        } catch {
            launchAtLogin = loginItemManager.isEnabled
            preferences.launchAtLoginRequested = launchAtLogin
            present(message: "无法更新登录时启动：\(error.localizedDescription)")
        }
    }

    private func recordForDay(startingAt start: Date) -> DailyWorkRecord? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }

        let segments: [WorkSegment] = dailyRecord?.segments.compactMap { segment -> WorkSegment? in
            if segment.startedAt >= nextDay {
                return nil
            }
            if let endedAt = segment.endedAt, endedAt <= start {
                return nil
            }

            let clippedStart = max(segment.startedAt, start)
            let clippedEnd = segment.endedAt.map { min($0, nextDay) }
            if let clippedEnd, clippedEnd <= clippedStart {
                return nil
            }

            let wasClipped = clippedStart != segment.startedAt || clippedEnd != segment.endedAt
            return WorkSegment(
                id: wasClipped ? UUID() : segment.id,
                startedAt: clippedStart,
                endedAt: clippedEnd,
                stopReason: clippedEnd == segment.endedAt ? segment.stopReason : nil,
                rate: segment.rate
            )
        } ?? []
        return segments.isEmpty ? nil : DailyWorkRecord(segments: segments)
    }

    @discardableResult
    private func persistCurrentState() -> Bool {
        let state = SecureState(
            settings: settings,
            dailyRecord: dailyRecord,
            dayStart: dayStart
        )
        do {
            try secureStore.save(state)
            return true
        } catch {
            present(error: error)
            return false
        }
    }

    private func registerForSystemEvents() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillPowerOff),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemTimeDidChange),
            name: .NSSystemClockDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemTimeDidChange),
            name: .NSSystemTimeZoneDidChange,
            object: nil
        )
    }

    @objc private func workspaceWillSleep() {
        handleSystemSleep()
    }

    @objc private func workspaceWillPowerOff() {
        handleSystemPowerOff()
    }

    @objc private func workspaceDidWake() {
        refreshDisplay(at: .now)
        restartEmotionalPromptSchedule(after: .now, includingCurrentMinute: true)
    }

    @objc private func systemTimeDidChange() {
        refreshDisplay(at: .now)
        restartEmotionalPromptSchedule(after: .now, includingCurrentMinute: true)
    }

    @objc private func applicationWillTerminate() {
        stopCurrentSession(reason: .quit, at: .now)
    }

    private func present(error: Error) {
        present(message: error.localizedDescription)
    }

    private func present(message: String) {
        errorMessage = message
        isShowingError = true
    }
}
