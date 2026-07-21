import XCTest
@testable import LlamaTopCore

final class ActivityTests: XCTestCase {
    func testNotFoundWithoutProcesses() {
        XCTAssertEqual(ActivityClassifier.classify(processes: [], gpuPercent: 80), .notFound)
    }

    func testBusyFromCPUActivity() {
        XCTAssertEqual(
            ActivityClassifier.classify(processes: [.fixture(cpuPercent: 12)], gpuPercent: 0),
            .busy
        )
    }

    func testDoesNotAttributeSystemGPUActivityToAnIdleLlamaProcess() {
        XCTAssertEqual(
            ActivityClassifier.classify(processes: [.fixture(cpuPercent: 0)], gpuPercent: 30),
            .idle
        )
    }

    func testIdleBelowNoiseThresholds() {
        XCTAssertEqual(
            ActivityClassifier.classify(processes: [.fixture(cpuPercent: 0.2)], gpuPercent: 2),
            .idle
        )
    }
}

private extension MonitoredProcess {
    static func fixture(cpuPercent: Double?) -> Self {
        .init(
            pid: 42,
            parentPID: 1,
            cpuPercent: cpuPercent,
            residentBytes: 1_024,
            elapsed: "00:01",
            executable: "llama-cli",
            command: "llama-cli -m model.gguf"
        )
    }
}
