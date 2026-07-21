import Foundation
import XCTest
@testable import LlamaTopCore

final class LlamaTopMonitorTests: XCTestCase {
    func testBuildsDeterministicSnapshotsFromInjectedProbesAndEnvironment() throws {
        let identity = ProcessIdentity(pid: 42, startSeconds: 10, startMicroseconds: 20)
        let processProbe = SequenceProcessProbe(frames: [
            [.fixture(identity: identity, cpuTicks: 100, residentBytes: 1_024)],
            [.fixture(identity: identity, cpuTicks: 220, residentBytes: 2_048)],
        ])
        let environment = SequenceEnvironment(ticks: [1_000, 1_100])
        let monitor = LlamaTopMonitor(
            processProbe: processProbe,
            gpuProbe: StubGPUProbe(percent: 42),
            matcher: LlamaProcessMatcher(),
            environment: environment
        )

        let warmup = monitor.nextSnapshot()
        let sampled = monitor.nextSnapshot()

        XCTAssertEqual(warmup.activity, .warmingUp)
        XCTAssertEqual(sampled.activity, .busy)
        XCTAssertEqual(sampled.machineName, "Test Mac")
        XCTAssertEqual(sampled.logicalCPUCount, 8)
        XCTAssertEqual(sampled.physicalMemoryBytes, 16_384)
        XCTAssertEqual(sampled.gpuPercent, 42)
        XCTAssertEqual(try XCTUnwrap(sampled.processes.first?.cpuPercent), 120, accuracy: 0.001)
        XCTAssertEqual(sampled.processes.first?.residentBytes, 2_048)
    }
}

private final class SequenceProcessProbe: ProcessProbing {
    private let frames: [[RawProcessSample]]
    private var index = 0

    init(frames: [[RawProcessSample]]) {
        self.frames = frames
    }

    func capture(at _: Date) -> [RawProcessSample] {
        defer { index += 1 }
        return frames[min(index, frames.count - 1)]
    }
}

private struct StubGPUProbe: GPUProbing {
    let percent: Double?

    func utilization() -> Double? {
        percent
    }
}

private final class SequenceEnvironment: MonitorEnvironment {
    let machineName = "Test Mac"
    let logicalCPUCount = 8
    let physicalMemoryBytes: UInt64 = 16_384
    private let ticks: [UInt64]
    private var index = 0

    init(ticks: [UInt64]) {
        self.ticks = ticks
    }

    func currentDate() -> Date {
        Date(timeIntervalSince1970: TimeInterval(index))
    }

    func currentUptimeTicks() -> UInt64 {
        defer { index += 1 }
        return ticks[min(index, ticks.count - 1)]
    }
}

private extension RawProcessSample {
    static func fixture(
        identity: ProcessIdentity,
        cpuTicks: UInt64,
        residentBytes: UInt64
    ) -> RawProcessSample {
        RawProcessSample(
            identity: identity,
            parentPID: 1,
            totalCPUTimeTicks: cpuTicks,
            residentBytes: residentBytes,
            elapsedSeconds: 5,
            executable: "/tmp/llama.cpp/build/bin/llama-cli",
            command: "llama-cli -m model.gguf"
        )
    }
}
