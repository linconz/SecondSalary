import Foundation

enum CurrencyOption: String, CaseIterable, Codable, Identifiable, Sendable {
    case cny = "CNY"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case hkd = "HKD"
    case sgd = "SGD"
    case aud = "AUD"
    case krw = "KRW"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cny: "人民币（CNY）"
        case .usd: "美元（USD）"
        case .eur: "欧元（EUR）"
        case .gbp: "英镑（GBP）"
        case .jpy: "日元（JPY）"
        case .hkd: "港币（HKD）"
        case .sgd: "新加坡元（SGD）"
        case .aud: "澳大利亚元（AUD）"
        case .krw: "韩元（KRW）"
        }
    }

    var fractionDigits: Int {
        switch self {
        case .jpy, .krw: 0
        default: 2
        }
    }

    func formatted(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        return value.formatted(
            .currency(code: rawValue)
                .precision(.fractionLength(fractionDigits))
        )
    }

    func formattedRate(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        return value.formatted(
            .currency(code: rawValue)
                .precision(.fractionLength(6))
        )
    }
}
