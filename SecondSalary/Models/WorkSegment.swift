import Foundation

struct WorkSegment: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var stopReason: StopReason?
    let rate: PayRateSnapshot

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        stopReason: StopReason? = nil,
        rate: PayRateSnapshot
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.stopReason = stopReason
        self.rate = rate
    }

    var isActive: Bool { endedAt == nil }

    func duration(at now: Date) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }

    func earnings(at now: Date) -> Decimal {
        rate.perSecond * Decimal(duration(at: now))
    }
}
