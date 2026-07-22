import Foundation
import XCTest
@testable import LlamaTopCore

final class MemoryProbeTests: XCTestCase {
    func testConvertsPageCountsToByteStatistics() throws {
        let statistics = MemoryStatisticsBuilder.build(
            counts: .init(
                active: 2,
                inactive: 3,
                wired: 4,
                compressed: 5,
                free: 6
            ),
            pageSizeBytes: 4_096,
            cacheLineBytes: 128,
            swapTotalBytes: 100_000,
            swapUsedBytes: 40_000,
            hardware: .init(memoryType: "LPDDR5", manufacturer: "Hynix")
        )

        XCTAssertEqual(statistics.activeBytes, 8_192)
        XCTAssertEqual(statistics.inactiveBytes, 12_288)
        XCTAssertEqual(statistics.wiredBytes, 16_384)
        XCTAssertEqual(statistics.compressedBytes, 20_480)
        XCTAssertEqual(statistics.freeBytes, 24_576)
        XCTAssertEqual(statistics.pageSizeBytes, 4_096)
        XCTAssertEqual(statistics.cacheLineBytes, 128)
        XCTAssertEqual(statistics.swapTotalBytes, 100_000)
        XCTAssertEqual(statistics.swapUsedBytes, 40_000)
        XCTAssertEqual(statistics.memoryType, "LPDDR5")
        XCTAssertEqual(statistics.manufacturer, "Hynix")
    }

    func testHardwareParserReadsStableSystemProfilerKeys() throws {
        let json = """
        {
          "SPMemoryDataType": [
            {
              "dimm_manufacturer": "Hynix",
              "dimm_type": "LPDDR5",
              "SPMemoryDataType": "128 GB"
            }
          ]
        }
        """

        let hardware = try XCTUnwrap(MemoryHardwareParser.parse(Data(json.utf8)))

        XCTAssertEqual(hardware.memoryType, "LPDDR5")
        XCTAssertEqual(hardware.manufacturer, "Hynix")
    }

    func testHardwareParserTreatsMissingFieldsAsUnavailable() {
        XCTAssertNil(MemoryHardwareParser.parse(Data(#"{"SPMemoryDataType": []}"#.utf8)))
        XCTAssertNil(MemoryHardwareParser.parse(Data("not json".utf8)))
    }
}
