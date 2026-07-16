import Foundation

enum EmotionalPrompt: String, Equatable, Sendable {
    case workStarted
    case waitingForWork
    case lunchChoice
    case lunchBreak
    case afternoonWakeUp
    case afternoonSleepy
    case almostOffWork
    case afterWork
    case fiveMinutesAfterWork

    func message(todayEarnings: String) -> String {
        switch self {
        case .workStarted:
            "新的一天开始了，今天也要努力搬砖哦"
        case .waitingForWork:
            "还未到工作时间"
        case .lunchChoice:
            "今天中午吃什么呢？是不是该点外卖了"
        case .lunchBreak:
            "休息一会，下午努力搬砖"
        case .afternoonWakeUp:
            "快醒醒，该搬砖了"
        case .afternoonSleepy:
            "打瞌睡了？别被老板看到"
        case .almostOffWork:
            "再忍一下，今日\(todayEarnings)即将到账"
        case .afterWork:
            "下班啦！"
        case .fiveMinutesAfterWork:
            "还没回家吗？"
        }
    }
}
