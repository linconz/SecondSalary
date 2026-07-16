import XCTest
@testable import SecondSalary

final class SecureStateCodingTests: XCTestCase {
    func testSecureStateRoundTripPreservesDecimalAndDates() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let settings = CompensationSettings(
            monthlySalary: Decimal(string: "12345.67") ?? 0,
            monthlyWorkdays: 22,
            workStartMinute: 8 * 60 + 30,
            workEndMinute: 16 * 60,
            currency: .eur
        )
        let rate = try XCTUnwrap(EarningsCalculator.rate(for: settings))
        let original = SecureState(
            settings: settings,
            dailyRecord: DailyWorkRecord(
                segments: [WorkSegment(startedAt: start, rate: rate)]
            ),
            dayStart: start
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SecureState.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testLegacySessionsMigrateToOneDailyRecord() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let settings = CompensationSettings(
            monthlySalary: 20_000,
            monthlyWorkdays: 21,
            workStartMinute: 9 * 60,
            workEndMinute: 17 * 60,
            currency: .cny
        )
        let rate = try XCTUnwrap(EarningsCalculator.rate(for: settings))
        let legacyState = LegacySecureState(
            version: 2,
            settings: settings,
            sessions: [
                WorkSegment(
                    startedAt: start,
                    endedAt: start.addingTimeInterval(600),
                    stopReason: .manual,
                    rate: rate
                ),
                WorkSegment(startedAt: start.addingTimeInterval(1_200), rate: rate)
            ],
            dayStart: start
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let data = try encoder.encode(legacyState)
        let decoded = try decoder.decode(SecureState.self, from: data)

        XCTAssertEqual(decoded.version, SecureState.currentVersion)
        XCTAssertEqual(decoded.dailyRecord?.segments, legacyState.sessions)
    }

    func testLegacyDailyHoursMigrateToWorkTimes() throws {
        let legacyJSON = Data(
            """
            {
              "monthlySalary": 20000,
              "monthlyWorkdays": 21,
              "dailyWorkHours": 7.5,
              "currency": "CNY"
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(CompensationSettings.self, from: legacyJSON)

        XCTAssertEqual(decoded.workStartMinute, CompensationSettings.defaultWorkStartMinute)
        XCTAssertEqual(decoded.workEndMinute, 16 * 60 + 30)
        XCTAssertEqual(decoded.scheduledWorkMinutes, 7 * 60 + 30)
    }
}
