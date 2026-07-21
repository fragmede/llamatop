import XCTest
@testable import LlamaTopCore

final class CommandSanitizerTests: XCTestCase {
    func testQuotesArgumentsWithSpaces() {
        XCTAssertEqual(
            CommandSanitizer.display(arguments: ["llama-cli", "-m", "My Model.gguf"]),
            "llama-cli -m \"My Model.gguf\""
        )
    }

    func testRedactsCommonSecretArguments() {
        let display = CommandSanitizer.display(arguments: [
            "llama-server",
            "--api-key", "secret-one",
            "--token=secret-two",
            "--hf-token", "secret-three",
        ])

        XCTAssertFalse(display.contains("secret-one"))
        XCTAssertFalse(display.contains("secret-two"))
        XCTAssertFalse(display.contains("secret-three"))
        XCTAssertEqual(display, "llama-server --api-key •••• --token=•••• --hf-token ••••")
    }
}
