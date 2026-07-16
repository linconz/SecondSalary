import Foundation

enum RefreshInterval: Int, CaseIterable, Codable, Identifiable, Sendable {
    case oneSecond = 1
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1_800
    case oneHour = 3_600

    var id: Int { rawValue }
    var timeInterval: TimeInterval { TimeInterval(rawValue) }

    var displayName: String {
        switch self {
        case .oneSecond: "每秒"
        case .fiveSeconds: "每 5 秒"
        case .tenSeconds: "每 10 秒"
        case .thirtySeconds: "每 30 秒"
        case .oneMinute: "每分钟"
        case .fiveMinutes: "每 5 分钟"
        case .fifteenMinutes: "每 15 分钟"
        case .thirtyMinutes: "每 30 分钟"
        case .oneHour: "每小时"
        }
    }
}
