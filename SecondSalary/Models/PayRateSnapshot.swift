import Foundation

struct PayRateSnapshot: Codable, Equatable, Sendable {
    let perSecond: Decimal
    let currency: CurrencyOption
}
