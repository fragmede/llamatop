import XCTest
@testable import LlamaTopCore

final class CPUCoreUsageCalculatorTests: XCTestCase {
    func testReturnsUnknownValuesForWarmupAndCoreCountChanges() {
        let current = [CPUCoreTicks(user: 10, system: 20, idle: 70, nice: 0)]

        XCTAssertEqual(CPUCoreUsageCalculator.percentages(previous: nil, current: current), [nil])
        XCTAssertEqual(
            CPUCoreUsageCalculator.percentages(previous: current + current, current: current),
            [nil]
        )
    }

    func testCalculatesBusyPercentageFromTickDeltas() throws {
        let percentages = CPUCoreUsageCalculator.percentages(
            previous: [.init(user: 10, system: 20, idle: 70, nice: 0)],
            current: [.init(user: 20, system: 40, idle: 130, nice: 0)]
        )

        XCTAssertEqual(try XCTUnwrap(percentages[0]), 33.333, accuracy: 0.001)
    }

    func testHandlesThirtyTwoBitCounterRollover() throws {
        let percentages = CPUCoreUsageCalculator.percentages(
            previous: [.init(user: UInt32.max - 4, system: 0, idle: 10, nice: 0)],
            current: [.init(user: 5, system: 0, idle: 100, nice: 0)]
        )

        XCTAssertEqual(try XCTUnwrap(percentages[0]), 10, accuracy: 0.001)
    }

    func testReturnsZeroWhenNoTicksAdvanced() throws {
        let ticks = [CPUCoreTicks(user: 10, system: 20, idle: 70, nice: 0)]
        let percentages = CPUCoreUsageCalculator.percentages(previous: ticks, current: ticks)

        XCTAssertEqual(try XCTUnwrap(percentages[0]), 0)
    }
}
