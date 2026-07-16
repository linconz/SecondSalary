import Foundation
@testable import SecondSalary

struct LegacySecureState: Encodable {
    let version: Int
    let settings: CompensationSettings?
    let sessions: [WorkSegment]
    let dayStart: Date
}
