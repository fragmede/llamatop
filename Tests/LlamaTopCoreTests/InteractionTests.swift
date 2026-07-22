import XCTest
@testable import LlamaTopCore

final class InteractionTests: XCTestCase {
    func testGlobalCommandsMapToTopStyleActions() {
        var state = DashboardDisplayState(
            mode: .summary,
            showsMemoryDetails: false,
            colorEnabled: true,
            allowsColor: true
        )

        XCTAssertEqual(state.action(for: UInt8(ascii: "s")), .promptRefreshInterval)
        XCTAssertEqual(state.action(for: UInt8(ascii: "d")), .promptRefreshInterval)
        XCTAssertEqual(state.action(for: UInt8(ascii: "n")), .promptProcessLimit)
        XCTAssertEqual(state.action(for: UInt8(ascii: "#")), .promptProcessLimit)
        XCTAssertEqual(state.action(for: UInt8(ascii: "o")), .promptSort)
        XCTAssertEqual(state.action(for: UInt8(ascii: "q")), .quit)
        XCTAssertEqual(state.action(for: UInt8(ascii: " ")), .refresh)
        XCTAssertEqual(state.action(for: 10), .refresh)
        XCTAssertEqual(state.action(for: 12), .redraw)
    }

    func testViewCommandsUpdateState() {
        var state = DashboardDisplayState(
            mode: .summary,
            showsMemoryDetails: false,
            colorEnabled: true,
            allowsColor: true
        )

        XCTAssertEqual(state.action(for: UInt8(ascii: "1")), .redraw)
        XCTAssertEqual(state.mode, .detailed)
        XCTAssertEqual(state.action(for: UInt8(ascii: "m")), .redraw)
        XCTAssertTrue(state.showsMemoryDetails)

        XCTAssertEqual(state.action(for: UInt8(ascii: "P")), .redraw)
        XCTAssertEqual(state.processSortKey, .cpu)
        XCTAssertEqual(state.action(for: UInt8(ascii: "M")), .redraw)
        XCTAssertEqual(state.processSortKey, .memory)
        XCTAssertEqual(state.action(for: UInt8(ascii: "T")), .redraw)
        XCTAssertEqual(state.processSortKey, .elapsedTime)
        XCTAssertEqual(state.action(for: UInt8(ascii: "N")), .redraw)
        XCTAssertEqual(state.processSortKey, .pid)
        XCTAssertEqual(state.action(for: UInt8(ascii: "C")), .redraw)
        XCTAssertEqual(state.processSortKey, .command)

        XCTAssertEqual(state.action(for: UInt8(ascii: "R")), .redraw)
        XCTAssertFalse(state.sortDescending)
        XCTAssertEqual(state.action(for: UInt8(ascii: "c")), .redraw)
        XCTAssertFalse(state.showsFullCommand)
        XCTAssertEqual(state.action(for: UInt8(ascii: "i")), .redraw)
        XCTAssertTrue(state.hidesIdleProcesses)
        XCTAssertEqual(state.action(for: UInt8(ascii: "z")), .redraw)
        XCTAssertFalse(state.colorEnabled)
    }

    func testHelpConsumesAnyNonQuitKeyAndReturnsToDashboard() {
        var state = DashboardDisplayState(mode: .summary, showsMemoryDetails: false)

        XCTAssertEqual(state.action(for: UInt8(ascii: "?")), .redraw)
        XCTAssertTrue(state.showsHelp)
        XCTAssertEqual(state.action(for: UInt8(ascii: "x")), .redraw)
        XCTAssertFalse(state.showsHelp)

        XCTAssertEqual(state.action(for: UInt8(ascii: "h")), .redraw)
        XCTAssertEqual(state.action(for: UInt8(ascii: "q")), .quit)
        XCTAssertFalse(state.showsHelp)
    }

    func testResetClearsViewRestrictionsAndDisabledColorStaysOff() {
        var state = DashboardDisplayState(mode: .summary, showsMemoryDetails: false)

        XCTAssertEqual(state.action(for: UInt8(ascii: "i")), .redraw)
        state.setProcessLimit(.maximum(3))
        XCTAssertEqual(state.action(for: UInt8(ascii: "=")), .redraw)
        XCTAssertFalse(state.hidesIdleProcesses)
        XCTAssertEqual(state.processLimit, .unlimited)

        XCTAssertEqual(state.action(for: UInt8(ascii: "z")), .none)
        XCTAssertFalse(state.colorEnabled)
    }

    func testPromptValueParsing() {
        XCTAssertEqual(RefreshInterval.parse("2.5"), 2.5)
        XCTAssertNil(RefreshInterval.parse("0.1"))
        XCTAssertNil(RefreshInterval.parse("nan"))
        XCTAssertNil(RefreshInterval.parse("later"))

        XCTAssertEqual(ProcessCountLimit.parse("20"), .maximum(20))
        XCTAssertEqual(ProcessCountLimit.parse("0"), .unlimited)
        XCTAssertNil(ProcessCountLimit.parse("-1"))

        XCTAssertEqual(ProcessSortKey.parse("ram"), .memory)
        XCTAssertEqual(ProcessSortKey.parse("time"), .elapsedTime)
        XCTAssertEqual(ProcessSortKey.parse("cmd"), .command)
        XCTAssertNil(ProcessSortKey.parse("temperature"))
    }
}
