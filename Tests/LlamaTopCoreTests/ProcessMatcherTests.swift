import XCTest
@testable import LlamaTopCore

final class ProcessMatcherTests: XCTestCase {
    private let matcher = LlamaProcessMatcher()

    func testMatchesModernLlamaCppExecutables() {
        XCTAssertTrue(matcher.matches(executable: "/usr/local/bin/llama-cli", command: "/usr/local/bin/llama-cli -m model.gguf"))
        XCTAssertTrue(matcher.matches(executable: "llama-server", command: "llama-server --port 8080"))
        XCTAssertTrue(matcher.matches(executable: "/tmp/llama.cpp/build/bin/main", command: "/tmp/llama.cpp/build/bin/main -m model.gguf"))
    }

    func testMatchesPythonLlamaCppServer() {
        XCTAssertTrue(matcher.matches(executable: "/usr/bin/python3", command: "/usr/bin/python3 -m llama_cpp.server --model model.gguf"))
    }

    func testRejectsGenericAndSelfProcesses() {
        XCTAssertFalse(matcher.matches(executable: "/usr/bin/main", command: "/usr/bin/main"))
        XCTAssertFalse(matcher.matches(executable: "/usr/local/bin/llamatop", command: "llamatop --once"))
        XCTAssertFalse(matcher.matches(executable: "/bin/zsh", command: "zsh -c echo llama.cpp"))
    }

    func testCustomMatchChecksTheFullCommandCaseInsensitively() {
        let matcher = LlamaProcessMatcher(customTerms: ["MY-INFERENCE-WORKER"])

        XCTAssertTrue(matcher.matches(executable: "/opt/worker", command: "/opt/worker my-inference-worker --serve"))
    }
}
