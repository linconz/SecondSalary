import XCTest
@testable import SecondSalary

final class EarningsCalculatorTests: XCTestCase {
    func testPlannedExampleEarnsAbout119AfterOneHour() throws {
        let settings = CompensationSettings(
            monthlySalary: 20_000,
            monthlyWorkdays: 21,
            workStartMinute: 9 * 60,
            workEndMinute: 17 * 60,
            currency: .cny
        )
        let rate = try XCTUnwrap(EarningsCalculator.rate(for: settings))
        let start = Date.now
        let segment = WorkSegment(startedAt: start, rate: rate)
        let earnings = segment.earnings(at: start.addingTimeInterval(3_600))

        XCTAssertEqual(NSDecimalNumber(decimal: earnings).doubleValue, 119.047619, accuracy: 0.000_001)
    }

    func testMultipleSegmentsAreAccumulated() throws {
        let settings = CompensationSettings(
            monthlySalary: 10_000,
            monthlyWorkdays: 20,
            workStartMinute: 9 * 60,
            workEndMinute: 17 * 60,
            currency: .cny
        )
        let rate = try XCTUnwrap(EarningsCalculator.rate(for: settings))
        let start = Date.now
        let segments = [
            WorkSegment(
                startedAt: start,
                endedAt: start.addingTimeInterval(1_800),
                stopReason: .manual,
                rate: rate
            ),
            WorkSegment(
                startedAt: start.addingTimeInterval(3_600),
                endedAt: start.addingTimeInterval(7_200),
                stopReason: .manual,
                rate: rate
            )
        ]

        XCTAssertEqual(EarningsCalculator.totalDuration(for: segments, at: start), 5_400)
        let earnings = EarningsCalculator.totalEarnings(for: segments, at: start)
        XCTAssertEqual(NSDecimalNumber(decimal: earnings).doubleValue, 93.75, accuracy: 0.000_001)
    }

    func testInvalidSettingsDoNotProduceARate() {
        let invalidSalary = CompensationSettings(
            monthlySalary: 0,
            monthlyWorkdays: 21,
            workStartMinute: 9 * 60,
            workEndMinute: 17 * 60,
            currency: .cny
        )
        let invalidWorkdays = CompensationSettings(
            monthlySalary: 20_000,
            monthlyWorkdays: 32,
            workStartMinute: 9 * 60,
            workEndMinute: 17 * 60,
            currency: .cny
        )
        let invalidWorkTime = CompensationSettings(
            monthlySalary: 20_000,
            monthlyWorkdays: 21,
            workStartMinute: 24 * 60,
            workEndMinute: 17 * 60,
            currency: .cny
        )
        let identicalWorkTimes = CompensationSettings(
            monthlySalary: 20_000,
            monthlyWorkdays: 21,
            workStartMinute: 9 * 60,
            workEndMinute: 9 * 60,
            currency: .cny
        )

        XCTAssertNil(EarningsCalculator.rate(for: invalidSalary))
        XCTAssertNil(EarningsCalculator.rate(for: invalidWorkdays))
        XCTAssertNil(EarningsCalculator.rate(for: invalidWorkTime))
        XCTAssertNil(EarningsCalculator.rate(for: identicalWorkTimes))
    }

    func testWorkTimesDetermineDailyDuration() {
        let daytime = CompensationSettings(
            monthlySalary: 20_000,
            monthlyWorkdays: 21,
            workStartMinute: 9 * 60,
            workEndMinute: 17 * 60 + 30,
            currency: .cny
        )
        let overnight = CompensationSettings(
            monthlySalary: 20_000,
            monthlyWorkdays: 21,
            workStartMinute: 22 * 60,
            workEndMinute: 6 * 60,
            currency: .cny
        )

        XCTAssertEqual(daytime.scheduledWorkMinutes, 8 * 60 + 30)
        XCTAssertEqual(overnight.scheduledWorkMinutes, 8 * 60)
    }

    func testCurrenciesUseExpectedMinorUnits() {
        XCTAssertEqual(CurrencyOption.cny.fractionDigits, 2)
        XCTAssertEqual(CurrencyOption.usd.fractionDigits, 2)
        XCTAssertEqual(CurrencyOption.jpy.fractionDigits, 0)
        XCTAssertEqual(CurrencyOption.krw.fractionDigits, 0)
    }
}
