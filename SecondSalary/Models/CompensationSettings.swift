import Foundation

struct CompensationSettings: Codable, Equatable, Sendable {
    static let defaultWorkStartMinute = 9 * 60
    static let defaultWorkEndMinute = 17 * 60

    let monthlySalary: Decimal
    let monthlyWorkdays: Int
    let workStartMinute: Int
    let workEndMinute: Int
    let currency: CurrencyOption

    var scheduledWorkMinutes: Int {
        Self.workDurationMinutes(from: workStartMinute, to: workEndMinute)
    }

    var scheduledWorkSeconds: Decimal {
        Decimal(scheduledWorkMinutes * 60)
    }

    var validationMessage: String? {
        if monthlySalary <= 0 {
            return "月薪必须大于 0。"
        }
        if !(1...31).contains(monthlyWorkdays) {
            return "当月工作日必须在 1 到 31 之间。"
        }
        if !(0..<Self.minutesPerDay).contains(workStartMinute)
            || !(0..<Self.minutesPerDay).contains(workEndMinute) {
            return "上班时间和下班时间无效。"
        }
        if workStartMinute == workEndMinute {
            return "上班时间和下班时间不能相同。"
        }
        return nil
    }

    var isValid: Bool { validationMessage == nil }

    init(
        monthlySalary: Decimal,
        monthlyWorkdays: Int,
        workStartMinute: Int,
        workEndMinute: Int,
        currency: CurrencyOption
    ) {
        self.monthlySalary = monthlySalary
        self.monthlyWorkdays = monthlyWorkdays
        self.workStartMinute = workStartMinute
        self.workEndMinute = workEndMinute
        self.currency = currency
    }

    static func workDurationMinutes(from startMinute: Int, to endMinute: Int) -> Int {
        guard (0..<minutesPerDay).contains(startMinute),
              (0..<minutesPerDay).contains(endMinute) else {
            return 0
        }

        return (endMinute - startMinute + minutesPerDay) % minutesPerDay
    }

    private static let minutesPerDay = 24 * 60

    private enum CodingKeys: String, CodingKey {
        case monthlySalary
        case monthlyWorkdays
        case workStartMinute
        case workEndMinute
        case currency
        case dailyWorkHours
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthlySalary = try container.decode(Decimal.self, forKey: .monthlySalary)
        monthlyWorkdays = try container.decode(Int.self, forKey: .monthlyWorkdays)
        currency = try container.decode(CurrencyOption.self, forKey: .currency)

        let decodedStart = try container.decodeIfPresent(Int.self, forKey: .workStartMinute)
        workStartMinute = decodedStart ?? Self.defaultWorkStartMinute

        if let decodedEnd = try container.decodeIfPresent(Int.self, forKey: .workEndMinute) {
            workEndMinute = decodedEnd
        } else {
            let legacyHours = try container.decodeIfPresent(Decimal.self, forKey: .dailyWorkHours)
            let legacyMinutes = legacyHours.map {
                Int(NSDecimalNumber(decimal: $0 * 60).doubleValue.rounded())
            } ?? Self.workDurationMinutes(
                from: Self.defaultWorkStartMinute,
                to: Self.defaultWorkEndMinute
            )
            let validLegacyMinutes = min(max(legacyMinutes, 1), Self.minutesPerDay - 1)
            workEndMinute = (workStartMinute + validLegacyMinutes) % Self.minutesPerDay
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monthlySalary, forKey: .monthlySalary)
        try container.encode(monthlyWorkdays, forKey: .monthlyWorkdays)
        try container.encode(workStartMinute, forKey: .workStartMinute)
        try container.encode(workEndMinute, forKey: .workEndMinute)
        try container.encode(currency, forKey: .currency)
    }
}
