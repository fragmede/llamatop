import XCTest
@testable import LlamaTopCore

final class CPUUsageCalculatorTests: XCTestCase {
    func testCalculatesTopStyleMulticorePercentage() {
        let percent = CPUUsageCalculator.percent(
            previousCPUTimeTicks: 1_000_000_000,
            currentCPUTimeTicks: 2_200_000_000,
            elapsedTicks: 1_000_000_000
        )

        XCTAssertEqual(percent ?? 0, 120, accuracy: 0.001)
    }

    func testReturnsNilForWarmupAndCounterRegression() {
        XCTAssertNil(CPUUsageCalculator.percent(
            previousCPUTimeTicks: nil,
            currentCPUTimeTicks: 1,
            elapsedTicks: 1
        ))
        XCTAssertNil(CPUUsageCalculator.percent(
            previousCPUTimeTicks: 10,
            currentCPUTimeTicks: 1,
            elapsedTicks: 1
        ))
    }

    func testReturnsNilForZeroElapsedTime() {
        XCTAssertNil(CPUUsageCalculator.percent(
            previousCPUTimeTicks: 1,
            currentCPUTimeTicks: 2,
            elapsedTicks: 0
        ))
    }
}
