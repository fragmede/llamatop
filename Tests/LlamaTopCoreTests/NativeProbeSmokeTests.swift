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
        XCTAssertGreaterThanOrEqual(current.totalCPUTimeTicks, 0)
    }

    func testGPUProbeReturnsAValidPercentageWhenSupported() {
        if let percent = AppleGPUProbe().utilization() {
            XCTAssertGreaterThanOrEqual(percent, 0)
            XCTAssertLessThanOrEqual(percent, 100)
        }
    }
}
