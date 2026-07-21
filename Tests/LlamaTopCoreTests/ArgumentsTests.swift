import XCTest
@testable import LlamaTopCore

final class ArgumentsTests: XCTestCase {
    func testDefaults() throws {
        let options = try Options.parse([])

        XCTAssertEqual(options.interval, 1)
        XCTAssertFalse(options.once)
        XCTAssertFalse(options.noColor)
        XCTAssertEqual(options.customMatchTerms, [])
    }

    func testParsesSupportedOptions() throws {
        let options = try Options.parse(["--once", "--no-color", "--interval", "2.5", "--match", "worker"])

        XCTAssertTrue(options.once)
        XCTAssertTrue(options.noColor)
        XCTAssertEqual(options.interval, 2.5)
        XCTAssertEqual(options.customMatchTerms, ["worker"])
    }

    func testRejectsUnsafeIntervals() {
        XCTAssertThrowsError(try Options.parse(["--interval", "0.01"]))
    }

    func testRecognizesHelpAndVersion() throws {
        XCTAssertTrue(try Options.parse(["--help"]).showHelp)
        XCTAssertTrue(try Options.parse(["--version"]).showVersion)
    }
}
