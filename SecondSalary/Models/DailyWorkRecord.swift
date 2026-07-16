import Foundation

struct DailyWorkRecord: Codable, Equatable, Sendable {
    var segments: [WorkSegment]

    init(segments: [WorkSegment] = []) {
        self.segments = segments
    }

    var isActive: Bool {
        segments.contains(where: \.isActive)
    }

    var activeRate: PayRateSnapshot? {
        segments.last(where: \.isActive)?.rate
    }

    var currency: CurrencyOption? {
        segments.first?.rate.currency
    }

    func duration(at now: Date) -> TimeInterval {
        EarningsCalculator.totalDuration(for: segments, at: now)
    }

    func earnings(at now: Date) -> Decimal {
        EarningsCalculator.totalEarnings(for: segments, at: now)
    }
}
