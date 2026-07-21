import XCTest
@testable import LlamaTopCore

final class RendererTests: XCTestCase {
    func testRendersVerdictMetricsProcessesAndGPUQualification() {
        let snapshot = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            machineName: "Apple M4 Max",
            logicalCPUCount: 16,
            physicalMemoryBytes: UInt64(64) * 1_024 * 1_024 * 1_024,
            gpuPercent: 75,
            processes: [
                .init(
                    pid: 123,
                    parentPID: 1,
                    cpuPercent: 420,
                    residentBytes: UInt64(8) * 1_024 * 1_024 * 1_024,
                    elapsed: "02:04",
                    executable: "llama-cli",
                    command: "llama-cli -m model.gguf"
                )
            ]
        )

        let output = DashboardRenderer(color: false, width: 100).render(snapshot)

        XCTAssertTrue(output.contains("BUSY"))
        XCTAssertTrue(output.contains("420.0%"))
        XCTAssertTrue(output.contains("4.2 cores"))
        XCTAssertTrue(output.contains("75.0% system-wide"))
        XCTAssertTrue(output.contains("8.0 GiB"))
        XCTAssertTrue(output.contains("llama-cli -m model.gguf"))
        XCTAssertTrue(output.contains("GPU is system-wide"))
    }

    func testRendersNotFoundHelpfully() {
        let snapshot = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            machineName: "Apple Silicon",
            logicalCPUCount: 8,
            physicalMemoryBytes: UInt64(16) * 1_024 * 1_024 * 1_024,
            gpuPercent: nil,
            processes: []
        )

        let output = DashboardRenderer(color: false, width: 80).render(snapshot)

        XCTAssertTrue(output.contains("NOT FOUND"))
        XCTAssertTrue(output.contains("--match"))
        XCTAssertTrue(output.contains("unavailable"))
    }
}
