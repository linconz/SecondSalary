import Foundation

enum EarningsCalculator {
    static func rate(for settings: CompensationSettings) -> PayRateSnapshot? {
        guard settings.isValid else { return nil }

        let secondsPerMonth = Decimal(settings.monthlyWorkdays)
            * settings.scheduledWorkSeconds
        return PayRateSnapshot(
            perSecond: settings.monthlySalary / secondsPerMonth,
            currency: settings.currency
        )
    }

    static func totalDuration(for segments: [WorkSegment], at now: Date) -> TimeInterval {
        segments.reduce(0) { partialResult, segment in
            partialResult + segment.duration(at: now)
        }
    }

    static func totalEarnings(for segments: [WorkSegment], at now: Date) -> Decimal {
        segments.reduce(Decimal.zero) { partialResult, segment in
            partialResult + segment.earnings(at: now)
        }
    }
}
