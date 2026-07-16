import XCTest
@testable import SecondSalary

@MainActor
final class AppModelTests: XCTestCase {
    func testFirstWorkSegmentStartsAtTodaysConfiguredWorkTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let today = calendar.startOfDay(for: .now)
        let clickTime = today.addingTimeInterval(10 * 3_600)
        let context = makeContext(calendar: calendar, now: clickTime)
        XCTAssertTrue(context.model.saveSettings(
            settings(),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))

        context.model.toggleSession(at: clickTime)

        XCTAssertEqual(
            context.model.dailyRecord?.segments.first?.startedAt,
            today.addingTimeInterval(9 * 3_600)
        )
        XCTAssertEqual(context.model.todayDuration(at: clickTime), 3_600)
        XCTAssertEqual(
            NSDecimalNumber(decimal: context.model.todayEarnings(at: clickTime)).doubleValue,
            119.047619,
            accuracy: 0.000_001
        )
    }

    func testStartingBeforeWorkTimeDoesNotAccumulateUntilScheduledStart() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = calendar.startOfDay(for: .now)
        let firstClick = day.addingTimeInterval(8 * 3_600)
        let workStart = day.addingTimeInterval(9 * 3_600)
        let context = makeContext(calendar: calendar, now: firstClick)
        XCTAssertTrue(context.model.saveSettings(
            settings(),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))

        context.model.toggleSession(at: firstClick)
        context.model.toggleSession(at: firstClick.addingTimeInterval(10 * 60))
        context.model.toggleSession(at: firstClick.addingTimeInterval(20 * 60))

        let record = try XCTUnwrap(context.model.dailyRecord)
        XCTAssertEqual(record.segments.count, 2)
        XCTAssertEqual(record.segments.last?.startedAt, workStart)
        XCTAssertEqual(
            context.model.statusHeaderMessage(at: firstClick.addingTimeInterval(20 * 60)),
            "还未到工作时间"
        )
        XCTAssertNotEqual(
            context.model.statusHeaderMessage(at: workStart),
            "还未到工作时间"
        )
        XCTAssertEqual(
            context.model.todayEarnings(at: workStart.addingTimeInterval(-1)),
            .zero
        )
        XCTAssertEqual(
            context.model.todayDuration(at: workStart.addingTimeInterval(30 * 60)),
            30 * 60
        )
    }

    func testStartingAfterWorkEndDoesNotAddMoreEarnings() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = calendar.startOfDay(for: .now)
        let workStart = day.addingTimeInterval(9 * 3_600)
        let manualStop = day.addingTimeInterval(10 * 3_600)
        let afterWork = day.addingTimeInterval(18 * 3_600)
        let nextWorkStart = day.addingTimeInterval((24 + 9) * 3_600)
        let context = makeContext(calendar: calendar, now: workStart)
        XCTAssertTrue(context.model.saveSettings(
            settings(),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))
        context.model.toggleSession(at: workStart)
        context.model.toggleSession(at: manualStop)
        let earningsBeforeAfterHoursStart = context.model.todayEarnings(at: manualStop)

        context.model.toggleSession(at: afterWork)

        XCTAssertEqual(context.model.dailyRecord?.segments.last?.startedAt, nextWorkStart)
        XCTAssertEqual(
            context.model.statusHeaderMessage(at: afterWork),
            "还未到工作时间"
        )
        XCTAssertEqual(
            context.model.todayEarnings(at: day.addingTimeInterval(23 * 3_600)),
            earningsBeforeAfterHoursStart
        )
    }

    func testOvernightScheduleDoesNotAccumulateBetweenShifts() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = calendar.startOfDay(for: .now)
        let afterWork = day.addingTimeInterval(7 * 3_600)
        let nextWorkStart = day.addingTimeInterval(22 * 3_600)
        let context = makeContext(calendar: calendar, now: afterWork)
        XCTAssertTrue(context.model.saveSettings(
            settings(
                workStartMinute: 22 * 60,
                workEndMinute: 6 * 60
            ),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))

        context.model.toggleSession(at: afterWork)

        XCTAssertEqual(context.model.dailyRecord?.segments.first?.startedAt, nextWorkStart)
        XCTAssertEqual(
            context.model.todayEarnings(at: nextWorkStart.addingTimeInterval(-1)),
            .zero
        )
        XCTAssertEqual(
            context.model.todayDuration(at: nextWorkStart.addingTimeInterval(60 * 60)),
            60 * 60
        )
    }

    func testRestartKeepsOneDailyRecordAndAvoidsDuplicateEarnings() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let today = calendar.startOfDay(for: .now)
        let firstClick = today.addingTimeInterval(10 * 3_600)
        let secondClick = today.addingTimeInterval(11 * 3_600)
        let context = makeContext(calendar: calendar, now: firstClick)
        XCTAssertTrue(context.model.saveSettings(
            settings(),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))

        context.model.toggleSession(at: firstClick)
        context.model.toggleSession(at: firstClick.addingTimeInterval(30 * 60))
        context.model.toggleSession(at: secondClick)

        let record = try XCTUnwrap(context.model.dailyRecord)
        XCTAssertEqual(record.segments.count, 2)
        XCTAssertEqual(record.segments.last?.startedAt, secondClick)
        XCTAssertEqual(context.model.todayDuration(at: secondClick), 90 * 60)
    }

    func testSegmentsKeepRateSnapshotsWhenSettingsChange() throws {
        let context = makeContext()
        let start = Date.now
        XCTAssertTrue(context.model.saveSettings(
            settings(salary: 20_000),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))
        context.model.toggleSession(at: start)
        let originalRate = try XCTUnwrap(
            context.model.dailyRecord?.segments.first?.rate.perSecond
        )

        XCTAssertTrue(context.model.saveSettings(
            settings(salary: 40_000),
            refreshInterval: .oneMinute,
            launchAtLogin: false
        ))
        XCTAssertEqual(context.model.dailyRecord?.segments.first?.rate.perSecond, originalRate)

        context.model.toggleSession(at: start.addingTimeInterval(60))
        context.model.toggleSession(at: start.addingTimeInterval(120))
        XCTAssertNotEqual(context.model.dailyRecord?.segments.last?.rate.perSecond, originalRate)
    }

    func testSleepStopsActiveSession() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let start = calendar.startOfDay(for: .now).addingTimeInterval(10 * 3_600)
        let context = makeContext(calendar: calendar, now: start)
        XCTAssertTrue(context.model.saveSettings(
            settings(workStartMinute: 10 * 60),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))
        context.model.toggleSession(at: start)

        context.model.handleSystemSleep(at: start.addingTimeInterval(300))

        let segment = try XCTUnwrap(context.model.dailyRecord?.segments.first)
        XCTAssertFalse(context.model.isWorking)
        XCTAssertEqual(segment.stopReason, .sleep)
        XCTAssertEqual(segment.duration(at: start), 300)
    }

    func testCrossingMidnightStartsANewTodaySegment() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let today = calendar.startOfDay(for: .now)
        let start = today.addingTimeInterval(23 * 3_600 + 30 * 60)
        let context = makeContext(calendar: calendar, now: start)
        XCTAssertTrue(context.model.saveSettings(
            settings(
                workStartMinute: 22 * 60,
                workEndMinute: 6 * 60
            ),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))
        context.model.toggleSession(at: start)

        let afterMidnight = today.addingTimeInterval(24 * 3_600 + 15 * 60)
        context.model.handleTick(at: afterMidnight)

        let record = try XCTUnwrap(context.model.dailyRecord)
        let segment = try XCTUnwrap(record.segments.first)
        XCTAssertEqual(record.segments.count, 1)
        XCTAssertEqual(segment.startedAt, today.addingTimeInterval(24 * 3_600))
        XCTAssertTrue(segment.isActive)
        XCTAssertEqual(context.model.todayDuration(at: afterMidnight), 15 * 60)
    }

    func testCurrencyChangeIsRejectedWhenTodayHasRecord() {
        let context = makeContext()
        let start = Date.now
        XCTAssertTrue(context.model.saveSettings(
            settings(currency: .cny),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))
        context.model.toggleSession(at: start)
        context.model.toggleSession(at: start.addingTimeInterval(10))

        XCTAssertFalse(context.model.saveSettings(
            settings(currency: .usd),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))
        XCTAssertEqual(context.model.settings?.currency, .cny)
        XCTAssertTrue(context.model.isShowingError)
    }

    func testPersistenceRestoresSettingsAndDailyRecord() {
        let store = InMemorySecureStateStore()
        let preferences = InMemoryPreferencesStore()
        let login = InMemoryLoginItemManager()
        let start = Date.now
        let first = AppModel(
            secureStore: store,
            preferences: preferences,
            loginItemManager: login,
            now: start,
            observesSystemEvents: false
        )
        XCTAssertTrue(first.saveSettings(
            settings(),
            refreshInterval: .thirtySeconds,
            showsEarningsInMenuBar: false,
            launchAtLogin: false
        ))
        first.toggleSession(at: start)
        first.toggleSession(at: start.addingTimeInterval(600))

        let restored = AppModel(
            secureStore: store,
            preferences: preferences,
            loginItemManager: login,
            now: start.addingTimeInterval(700),
            observesSystemEvents: false
        )

        XCTAssertEqual(restored.settings, first.settings)
        XCTAssertEqual(restored.dailyRecord, first.dailyRecord)
        XCTAssertEqual(restored.refreshInterval, .thirtySeconds)
        XCTAssertFalse(restored.showsEarningsInMenuBar)
    }

    func testRefreshIntervalDoesNotChangeEarnings() {
        let context = makeContext()
        let start = Date.now
        XCTAssertTrue(context.model.saveSettings(
            settings(),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))
        context.model.toggleSession(at: start)
        let checkpoint = start.addingTimeInterval(3_600)
        let before = context.model.todayEarnings(at: checkpoint)

        XCTAssertTrue(context.model.saveSettings(
            settings(),
            refreshInterval: .oneHour,
            launchAtLogin: false
        ))
        let after = context.model.todayEarnings(at: checkpoint)

        XCTAssertEqual(before, after)
    }

    func testLoginItemFailureIsPresentedToTheUser() {
        let store = InMemorySecureStateStore()
        let login = InMemoryLoginItemManager()
        login.shouldFail = true
        let model = AppModel(
            secureStore: store,
            preferences: InMemoryPreferencesStore(),
            loginItemManager: login,
            observesSystemEvents: false
        )

        XCTAssertTrue(model.saveSettings(
            settings(),
            refreshInterval: .oneSecond,
            launchAtLogin: true
        ))
        XCTAssertFalse(model.launchAtLogin)
        XCTAssertTrue(model.isShowingError)
        XCTAssertTrue(model.errorMessage.localizedStandardContains("登录时启动"))
    }

    func testResetDeletesSecureStateAndDisablesLoginItem() {
        let store = InMemorySecureStateStore()
        let preferences = InMemoryPreferencesStore()
        let login = InMemoryLoginItemManager()
        let model = AppModel(
            secureStore: store,
            preferences: preferences,
            loginItemManager: login,
            observesSystemEvents: false
        )
        XCTAssertTrue(model.saveSettings(
            settings(),
            refreshInterval: .oneMinute,
            showsEarningsInMenuBar: false,
            launchAtLogin: true
        ))
        model.toggleSession()

        model.resetAllData()

        XCTAssertNil(store.state)
        XCTAssertNil(model.settings)
        XCTAssertNil(model.dailyRecord)
        XCTAssertFalse(model.launchAtLogin)
        XCTAssertEqual(model.refreshInterval, .oneSecond)
        XCTAssertTrue(model.showsEarningsInMenuBar)
        XCTAssertTrue(preferences.showsEarningsInMenuBar)
    }

    func testPersistenceLoadFailureIsPresented() {
        let store = InMemorySecureStateStore()
        store.error = TestServiceError.expectedFailure

        let model = AppModel(
            secureStore: store,
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            observesSystemEvents: false
        )

        XCTAssertTrue(model.isShowingError)
        XCTAssertTrue(model.errorMessage.localizedStandardContains("预期的测试错误"))
    }

    func testEmotionalPromptUsesFormattedTodayEarnings() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let start = calendar.startOfDay(for: .now).addingTimeInterval(9 * 3_600)
        let context = makeContext(calendar: calendar, now: start)
        XCTAssertTrue(context.model.saveSettings(
            settings(),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))
        context.model.toggleSession(at: start)
        let promptTime = start.addingTimeInterval(7.5 * 3_600)

        context.model.presentEmotionalPrompts([.almostOffWork], at: promptTime)

        XCTAssertEqual(
            context.model.emotionalPrompt?.message,
            "再忍一下，今日\(context.model.formattedTodayEarnings(at: promptTime))即将到账"
        )
        XCTAssertEqual(
            context.model.statusHeaderMessage,
            context.model.emotionalPrompt?.message
        )
    }

    func testFirstWorkSessionShowsStartPromptAfterDelay() async throws {
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: .now).addingTimeInterval(10 * 60 * 60)
        let model = AppModel(
            secureStore: InMemorySecureStateStore(),
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            calendar: calendar,
            now: start,
            observesSystemEvents: false,
            workStartedPromptDelay: .milliseconds(10)
        )
        XCTAssertTrue(model.saveSettings(
            settings(),
            refreshInterval: .oneSecond,
            launchAtLogin: false
        ))

        model.toggleSession(at: start)
        try await Task.sleep(for: .milliseconds(30))

        XCTAssertEqual(model.emotionalPrompt?.prompt, .workStarted)
        XCTAssertEqual(
            model.emotionalPrompt?.message,
            "新的一天开始了，今天也要努力搬砖哦"
        )
    }

    func testSimultaneousPromptsArePresentedInOrder() async throws {
        let model = AppModel(
            secureStore: InMemorySecureStateStore(),
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            observesSystemEvents: false,
            emotionalPromptDisplayDuration: .milliseconds(100)
        )

        model.presentEmotionalPrompts(
            [.afternoonSleepy, .almostOffWork],
            at: .now
        )
        XCTAssertEqual(model.emotionalPrompt?.prompt, .afternoonSleepy)

        try await Task.sleep(for: .milliseconds(120))

        XCTAssertEqual(model.emotionalPrompt?.prompt, .almostOffWork)
    }

    func testStatusHeaderKeepsLastPromptAfterBubbleDismisses() async throws {
        let model = AppModel(
            secureStore: InMemorySecureStateStore(),
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            observesSystemEvents: false,
            emotionalPromptDisplayDuration: .milliseconds(10)
        )

        model.presentEmotionalPrompts([.almostOffWork], at: .now)
        let expectedMessage = model.emotionalPrompt?.message
        try await Task.sleep(for: .milliseconds(30))

        XCTAssertNil(model.emotionalPrompt)
        XCTAssertEqual(model.statusHeaderMessage, expectedMessage)
        XCTAssertTrue(model.statusHeaderMessage?.hasPrefix("再忍一下，今日") == true)
    }

    func testSavingWorkEndReschedulesCurrentAlmostOffWorkMinute() async {
        let now = Date.now
        let calendar = Calendar.autoupdatingCurrent
        let currentMinute = calendar.component(.hour, from: now) * 60
            + calendar.component(.minute, from: now)
        let workEndMinute = (currentMinute + 30) % (24 * 60)
        let model = AppModel(
            secureStore: InMemorySecureStateStore(),
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            calendar: calendar,
            now: now,
            observesSystemEvents: false,
            emotionalPromptDisplayDuration: .milliseconds(10)
        )

        XCTAssertTrue(model.saveSettings(
            settings(workEndMinute: workEndMinute),
            refreshInterval: .oneHour,
            launchAtLogin: false
        ))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(model.statusHeaderMessage?.hasPrefix("再忍一下，今日") == true)
    }

    func testStatusHeaderDerivesAlmostOffWorkMessageWhenOpenedAfterTrigger() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 15
        )))
        let workStart = try XCTUnwrap(calendar.date(
            bySettingHour: 9,
            minute: 30,
            second: 0,
            of: day
        ))
        let now = try XCTUnwrap(calendar.date(
            bySettingHour: 18,
            minute: 36,
            second: 0,
            of: day
        ))
        let configuredSettings = settings(workEndMinute: 19 * 60)
        let rate = try XCTUnwrap(EarningsCalculator.rate(for: configuredSettings))
        let store = InMemorySecureStateStore()
        store.state = SecureState(
            settings: configuredSettings,
            dailyRecord: DailyWorkRecord(segments: [
                WorkSegment(startedAt: workStart, rate: rate)
            ]),
            dayStart: day
        )
        let model = AppModel(
            secureStore: store,
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            calendar: calendar,
            now: now,
            observesSystemEvents: false
        )

        XCTAssertNil(model.statusHeaderMessage)
        XCTAssertEqual(
            model.statusHeaderMessage(at: now),
            "再忍一下，今日\(model.formattedTodayEarnings(at: now))即将到账"
        )

        let workEnd = try XCTUnwrap(calendar.date(
            bySettingHour: 19,
            minute: 0,
            second: 0,
            of: day
        ))
        XCTAssertEqual(model.statusHeaderMessage(at: workEnd), "下班啦！")
        XCTAssertEqual(
            model.statusHeaderMessage(at: workEnd.addingTimeInterval(5 * 60)),
            "还没回家吗？"
        )
        XCTAssertEqual(
            model.statusHeaderMessage(at: workEnd.addingTimeInterval(60 * 60 - 1)),
            "还没回家吗？"
        )
        XCTAssertEqual(
            model.statusHeaderMessage(at: workEnd.addingTimeInterval(60 * 60)),
            EmotionalPrompt.workStarted.message(
                todayEarnings: model.formattedTodayEarnings(at: workEnd)
            )
        )
    }

    func testFiveMinutesAfterWorkUpdatesBubbleAndStatusHeaderTogether() {
        let model = AppModel(
            secureStore: InMemorySecureStateStore(),
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            observesSystemEvents: false
        )

        model.presentEmotionalPrompts([.fiveMinutesAfterWork], at: .now)

        XCTAssertEqual(model.emotionalPrompt?.message, "还没回家吗？")
        XCTAssertEqual(model.statusHeaderMessage, "还没回家吗？")
    }

    func testScheduledWorkEndStopsEarningsAtConfiguredTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = calendar.startOfDay(for: .now)
        let workStart = day.addingTimeInterval(9 * 3_600)
        let workEnd = day.addingTimeInterval(19 * 3_600)
        let configuredSettings = settings(workEndMinute: 19 * 60)
        let rate = try XCTUnwrap(EarningsCalculator.rate(for: configuredSettings))
        let store = InMemorySecureStateStore()
        store.state = SecureState(
            settings: configuredSettings,
            dailyRecord: DailyWorkRecord(segments: [
                WorkSegment(startedAt: workStart, rate: rate)
            ]),
            dayStart: day
        )
        let model = AppModel(
            secureStore: store,
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            calendar: calendar,
            now: workEnd.addingTimeInterval(-1),
            observesSystemEvents: false
        )

        model.refreshDisplay(at: workEnd)

        let segment = try XCTUnwrap(model.dailyRecord?.segments.first)
        XCTAssertFalse(model.isWorking)
        XCTAssertEqual(segment.endedAt, workEnd)
        XCTAssertEqual(segment.stopReason, .scheduledWorkEnd)
        XCTAssertEqual(
            model.todayEarnings(at: workEnd),
            model.todayEarnings(at: workEnd.addingTimeInterval(3_600))
        )
    }

    func testLaunchAfterWorkEndTruncatesActiveSegmentToScheduledTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = calendar.startOfDay(for: .now)
        let workStart = day.addingTimeInterval(9 * 3_600)
        let workEnd = day.addingTimeInterval(19 * 3_600)
        let configuredSettings = settings(workEndMinute: 19 * 60)
        let rate = try XCTUnwrap(EarningsCalculator.rate(for: configuredSettings))
        let store = InMemorySecureStateStore()
        store.state = SecureState(
            settings: configuredSettings,
            dailyRecord: DailyWorkRecord(segments: [
                WorkSegment(startedAt: workStart, rate: rate)
            ]),
            dayStart: day
        )

        let model = AppModel(
            secureStore: store,
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            calendar: calendar,
            now: workEnd.addingTimeInterval(10 * 60),
            observesSystemEvents: false
        )

        XCTAssertFalse(model.isWorking)
        XCTAssertEqual(model.dailyRecord?.segments.first?.endedAt, workEnd)
        XCTAssertEqual(
            model.dailyRecord?.segments.first?.stopReason,
            .scheduledWorkEnd
        )
    }

    private func makeContext(
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = .now
    ) -> (model: AppModel, store: InMemorySecureStateStore) {
        let store = InMemorySecureStateStore()
        let model = AppModel(
            secureStore: store,
            preferences: InMemoryPreferencesStore(),
            loginItemManager: InMemoryLoginItemManager(),
            calendar: calendar,
            now: now,
            observesSystemEvents: false
        )
        return (model, store)
    }

    private func settings(
        salary: Decimal = 20_000,
        currency: CurrencyOption = .cny,
        workStartMinute: Int = 9 * 60,
        workEndMinute: Int = 17 * 60
    ) -> CompensationSettings {
        CompensationSettings(
            monthlySalary: salary,
            monthlyWorkdays: 21,
            workStartMinute: workStartMinute,
            workEndMinute: workEndMinute,
            currency: currency
        )
    }
}
