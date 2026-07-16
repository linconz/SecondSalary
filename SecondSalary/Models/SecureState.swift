import Foundation

struct SecureState: Codable, Equatable, Sendable {
    static let currentVersion = 3

    var version: Int
    var settings: CompensationSettings?
    var dailyRecord: DailyWorkRecord?
    var dayStart: Date

    init(
        version: Int = SecureState.currentVersion,
        settings: CompensationSettings? = nil,
        dailyRecord: DailyWorkRecord? = nil,
        dayStart: Date
    ) {
        self.version = version
        self.settings = settings
        self.dailyRecord = dailyRecord
        self.dayStart = dayStart
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = Self.currentVersion
        settings = try container.decodeIfPresent(CompensationSettings.self, forKey: .settings)
        dayStart = try container.decode(Date.self, forKey: .dayStart)

        if let decodedRecord = try container.decodeIfPresent(
            DailyWorkRecord.self,
            forKey: .dailyRecord
        ) {
            dailyRecord = decodedRecord
        } else {
            let legacySegments = try container.decodeIfPresent(
                [WorkSegment].self,
                forKey: .sessions
            ) ?? []
            dailyRecord = legacySegments.isEmpty ? nil : DailyWorkRecord(segments: legacySegments)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentVersion, forKey: .version)
        try container.encodeIfPresent(settings, forKey: .settings)
        try container.encodeIfPresent(dailyRecord, forKey: .dailyRecord)
        try container.encode(dayStart, forKey: .dayStart)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case settings
        case dailyRecord
        case sessions
        case dayStart
    }
}
