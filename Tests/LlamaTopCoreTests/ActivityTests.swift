import XCTest
@testable import LlamaTopCore

final class ActivityTests: XCTestCase {
    func testNotFoundWithoutProcesses() {
        XCTAssertEqual(ActivityClassifier.classify(processes: []), .notFound)
    }

    func testBusyFromCPUActivity() {
        XCTAssertEqual(
            ActivityClassifier.classify(processes: [.fixture(cpuPercent: 12)]),
            .busy
        )
    }

    func testClassifiesKnownLowCPUAsIdle() {
        XCTAssertEqual(
            ActivityClassifier.classify(processes: [.fixture(cpuPercent: 0)]),
            .idle
        )
    }

    func testReportsWarmingUpWhenCPUIsNotKnownYet() {
        XCTAssertEqual(
            ActivityClassifier.classify(processes: [.fixture(cpuPercent: nil)]),
            .warmingUp
        )
    }

    func testIdleBelowNoiseThresholds() {
        XCTAssertEqual(
            ActivityClassifier.classify(processes: [.fixture(cpuPercent: 0.2)]),
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
            elapsedSeconds: 1,
            executable: "llama-cli",
            command: "llama-cli -m model.gguf"
        )
    }
}
