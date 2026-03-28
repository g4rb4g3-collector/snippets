import XCTest
@testable import MiniChart

final class MiniChartTests: XCTestCase {
    func testInitWithDefaults() {
        let view = MiniChartView(data: [1.0, 2.0, 3.0])
        XCTAssertEqual(view.data, [1.0, 2.0, 3.0])
        XCTAssertEqual(view.lineWidth, 2)
    }

    func testInitWithCustomValues() {
        let view = MiniChartView(data: [5, 10], lineWidth: 4)
        XCTAssertEqual(view.data, [5, 10])
        XCTAssertEqual(view.lineWidth, 4)
    }

    func testEmptyData() {
        let view = MiniChartView(data: [])
        XCTAssertTrue(view.data.isEmpty)
    }

    func testSingleDataPoint() {
        let view = MiniChartView(data: [42.0])
        XCTAssertEqual(view.data.count, 1)
    }
}
