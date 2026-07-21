import XCTest
@testable import LlamaTopCore

final class GPUParserTests: XCTestCase {
    func testParsesDeviceUtilizationFromIORegistry() {
        let properties: [String: Any] = [
            "PerformanceStatistics": [
                "Tiler Utilization %": 2,
                "Renderer Utilization %": 3,
                "Device Utilization %": 96,
            ],
        ]

        XCTAssertEqual(GPUUtilizationParser.parse(properties), 96)
    }

    func testReturnsNilWhenMetricIsUnavailable() {
        XCTAssertNil(GPUUtilizationParser.parse(["PerformanceStatistics": ["Renderer Utilization %": 3]]))
    }

    func testAcceptsStringValuesAndClampsInvalidDriverValues() {
        XCTAssertEqual(GPUUtilizationParser.parse(["Device Utilization %": "145"]), 100)
    }
}
