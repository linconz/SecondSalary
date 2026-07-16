import XCTest
@testable import SecondSalary

final class EmotionalPromptScheduleTests: XCTestCase {
    func testFixedPromptsUseExpectedTimes() throws {
        let context = try makeContext()

        let occurrence = try XCTUnwrap(
            context.schedule.nextOccurrence(
                after: context.date(11, 29),
                settings: context.settings
            )
        )

        XCTAssertEqual(occurrence.date, context.date(11, 30))
        XCTAssertEqual(occurrence.prompts, [.lunchChoice])
    }

    func testDefaultWorkEndQueuesBothPromptsAtFourThirty() throws {
        let context = try makeContext()

        let occurrence = try XCTUnwrap(
            context.schedule.nextOccurrence(
                after: context.date(16, 29),
                settings: context.settings
            )
        )

        XCTAssertEqual(occurrence.date, context.date(16, 30))
        XCTAssertEqual(occurrence.prompts, [.afternoonSleepy, .almostOffWork])
    }

    func testWorkEndPromptsFollowConfiguredEndTime() throws {
        let context = try makeContext(workEndMinute: 19 * 60)

        let beforeWorkEnd = try XCTUnwrap(
            context.schedule.nextOccurrence(
                after: context.date(16, 30),
                settings: context.settings
            )
        )
        let workEnd = try XCTUnwrap(
            context.schedule.nextOccurrence(
                after: beforeWorkEnd.date,
                settings: context.settings
            )
        )
        let fiveMinutesAfterWork = try XCTUnwrap(
            context.schedule.nextOccurrence(
                after: workEnd.date,
                settings: context.settings
            )
        )
        let oneHourAfterWork = try XCTUnwrap(
            context.schedule.nextOccurrence(
                after: fiveMinutesAfterWork.date,
                settings: context.settings
            )
        )

        XCTAssertEqual(beforeWorkEnd.date, context.date(18, 30))
        XCTAssertEqual(beforeWorkEnd.prompts, [.almostOffWork])
        XCTAssertEqual(workEnd.date, context.date(19, 0))
        XCTAssertEqual(workEnd.prompts, [.afterWork])
        XCTAssertEqual(fiveMinutesAfterWork.date, context.date(19, 5))
        XCTAssertEqual(fiveMinutesAfterWork.prompts, [.fiveMinutesAfterWork])
        XCTAssertEqual(oneHourAfterWork.date, context.date(20, 0))
        XCTAssertEqual(oneHourAfterWork.prompts, [.workStarted])
    }

    func testConfiguredWorkEndReminderMatchesCurrentTriggerMinute() throws {
        let context = try makeContext(workEndMinute: 19 * 60)

        let occurrence = try XCTUnwrap(
            context.schedule.nextOccurrence(
                after: context.date(18, 30).addingTimeInterval(45),
                includingCurrentMinute: true,
                settings: context.settings
            )
        )

        XCTAssertEqual(occurrence.date, context.date(18, 30))
        XCTAssertEqual(occurrence.prompts, [.almostOffWork])
    }

    private func makeContext(
        workEndMinute: Int = 17 * 60
    ) throws -> (
        schedule: EmotionalPromptSchedule,
        settings: CompensationSettings,
        date: (Int, Int) -> Date
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 15
        )))
        let date: (Int, Int) -> Date = { hour, minute in
            calendar.date(
                byAdding: .minute,
                value: hour * 60 + minute,
                to: day
            )!
        }
        let settings = CompensationSettings(
            monthlySalary: 20_000,
            monthlyWorkdays: 21,
            workStartMinute: 9 * 60,
            workEndMinute: workEndMinute,
            currency: .cny
        )
        return (EmotionalPromptSchedule(calendar: calendar), settings, date)
    }
}
