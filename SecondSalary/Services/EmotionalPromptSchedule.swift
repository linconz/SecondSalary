import Foundation

struct EmotionalPromptSchedule: Sendable {
    struct Occurrence: Equatable, Sendable {
        let date: Date
        let prompts: [EmotionalPrompt]
    }

    private let calendar: Calendar

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func nextOccurrence(
        after date: Date,
        includingCurrentMinute: Bool = false,
        settings: CompensationSettings
    ) -> Occurrence? {
        let events = scheduledEvents(settings: settings)
        let today = calendar.startOfDay(for: date)
        let currentMinuteStart = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        var candidates: [(date: Date, prompt: EmotionalPrompt)] = []

        for dayOffset in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }

            for event in events {
                guard let candidate = calendar.date(
                    bySettingHour: event.minuteOfDay / 60,
                    minute: event.minuteOfDay % 60,
                    second: 0,
                    of: day
                ) else {
                    continue
                }
                let isEligible = includingCurrentMinute
                    ? candidate >= currentMinuteStart
                    : candidate > date
                guard isEligible else { continue }
                candidates.append((candidate, event.prompt))
            }
        }

        guard let nextDate = candidates.map(\.date).min() else { return nil }
        let prompts = candidates
            .filter { $0.date == nextDate }
            .map(\.prompt)
        return Occurrence(date: nextDate, prompts: prompts)
    }

    private func scheduledEvents(
        settings: CompensationSettings
    ) -> [(minuteOfDay: Int, prompt: EmotionalPrompt)] {
        let minutesPerDay = 24 * 60
        let beforeWorkEnd = (settings.workEndMinute - 30 + minutesPerDay) % minutesPerDay
        let fiveMinutesAfterWorkEnd = (settings.workEndMinute + 5) % minutesPerDay
        let oneHourAfterWorkEnd = (settings.workEndMinute + 60) % minutesPerDay

        return [
            (11 * 60 + 30, .lunchChoice),
            (12 * 60 + 30, .lunchBreak),
            (13 * 60 + 30, .afternoonWakeUp),
            (16 * 60 + 30, .afternoonSleepy),
            (beforeWorkEnd, .almostOffWork),
            (settings.workEndMinute, .afterWork),
            (fiveMinutesAfterWorkEnd, .fiveMinutesAfterWork),
            (oneHourAfterWorkEnd, .workStarted)
        ]
    }
}
