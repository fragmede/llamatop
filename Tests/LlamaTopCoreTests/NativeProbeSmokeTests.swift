import Darwin
import Foundation
import XCTest
@testable import LlamaTopCore

final class NativeProbeSmokeTests: XCTestCase {
    func testProcessProbeCanReadTheCurrentProcess() throws {
        let samples = DarwinProcessProbe().capture(at: Date())
        let current = try XCTUnwrap(samples.first { $0.identity.pid == getpid() })

        XCTAssertFalse(current.executable.isEmpty)
        XCTAssertGreaterThan(current.residentBytes, 0)
        XCTAssertGreaterThan(current.totalCPUTimeTicks, 0)
    }

    func testCPUCoreProbeReturnsCumulativeTicks() throws {
        let cores = try XCTUnwrap(DarwinCPUCoreProbe().capture())

        XCTAssertFalse(cores.isEmpty)
        XCTAssertTrue(cores.allSatisfy { $0.user &+ $0.system &+ $0.idle &+ $0.nice > 0 })
    }

    func testGPUProbeReturnsValidStatisticsWhenSupported() {
        if let statistics = AppleGPUProbe().capture() {
            for percent in [
                statistics.devicePercent,
                statistics.rendererPercent,
                statistics.tilerPercent,
            ].compactMap({ $0 }) {
                XCTAssertGreaterThanOrEqual(percent, 0)
                XCTAssertLessThanOrEqual(percent, 100)
            }
            if let coreCount = statistics.coreCount {
                XCTAssertGreaterThan(coreCount, 0)
            }
        }
    }
}
