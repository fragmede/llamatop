import XCTest
@testable import LlamaTopCore

final class GPUParserTests: XCTestCase {
    func testParsesIndependentUtilizationMemoryAndHardwareFields() throws {
        let performance: [String: Any] = [
            "Tiler Utilization %": 2,
            "Renderer Utilization %": 3,
            "Device Utilization %": 96,
            "Alloc system memory": UInt64(58_957_414_400),
            "In use system memory": UInt64(48_213_934_080),
        ]

        let stats = try XCTUnwrap(GPUStatisticsParser.parse(
            performanceStatistics: performance,
            coreCount: NSNumber(value: 40),
            model: "Apple M4 Max"
        ))

        XCTAssertEqual(stats.model, "Apple M4 Max")
        XCTAssertEqual(stats.coreCount, 40)
        XCTAssertEqual(stats.devicePercent, 96)
        XCTAssertEqual(stats.rendererPercent, 3)
        XCTAssertEqual(stats.tilerPercent, 2)
        XCTAssertEqual(stats.allocatedSystemMemoryBytes, 58_957_414_400)
        XCTAssertEqual(stats.inUseSystemMemoryBytes, 48_213_934_080)
    }

    func testKeepsEachMetricOptional() throws {
        let stats = try XCTUnwrap(GPUStatisticsParser.parse(
            performanceStatistics: ["Renderer Utilization %": 25],
            coreCount: nil,
            model: nil
        ))

        XCTAssertNil(stats.devicePercent)
        XCTAssertEqual(stats.rendererPercent, 25)
        XCTAssertNil(stats.tilerPercent)
    }

    func testAcceptsStringsClampsPercentagesAndRejectsNegativeSizes() throws {
        let stats = try XCTUnwrap(GPUStatisticsParser.parse(
            performanceStatistics: [
                "Device Utilization %": "145",
                "Renderer Utilization %": "-5",
                "In use system memory": -1,
            ],
            coreCount: "40",
            model: 123
        ))

        XCTAssertEqual(stats.devicePercent, 100)
        XCTAssertEqual(stats.rendererPercent, 0)
        XCTAssertNil(stats.inUseSystemMemoryBytes)
        XCTAssertEqual(stats.coreCount, 40)
        XCTAssertNil(stats.model)
    }

    func testReturnsNilWhenEveryFieldIsUnavailable() {
        XCTAssertNil(GPUStatisticsParser.parse(
            performanceStatistics: ["unrelated": true],
            coreCount: nil,
            model: nil
        ))
    }
}
