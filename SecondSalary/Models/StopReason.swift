import Foundation

enum StopReason: String, Codable, Sendable {
    case manual
    case scheduledWorkEnd
    case sleep
    case powerOff
    case quit

    var displayName: String {
        switch self {
        case .manual: "手动结束"
        case .scheduledWorkEnd: "到达下班时间"
        case .sleep: "系统睡眠"
        case .powerOff: "关机或注销"
        case .quit: "退出应用"
        }
    }
}
