import XCTest
@testable import SecondSalary

final class DurationTextTests: XCTestCase {
    func testDurationFormatting() {
        XCTAssertEqual(DurationText.formatted(seconds: 0), "0:00:00")
        XCTAssertEqual(DurationText.formatted(seconds: 3_661), "1:01:01")
        XCTAssertEqual(DurationText.formatted(seconds: -10), "0:00:00")
    }
}
