import Foundation

public struct LlamaProcessMatcher: Sendable {
    private let customTerms: [String]

    public init(customTerms: [String] = []) {
        self.customTerms = customTerms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    public func matches(executable: String, command: String) -> Bool {
        let loweredPath = executable.lowercased()
        let basename = URL(fileURLWithPath: loweredPath).lastPathComponent
        let loweredCommand = command.lowercased()

        if basename == "llamatop" || basename == "llama-top" {
            return false
        }
        if basename.hasPrefix("llama-") {
            return true
        }
        if (basename == "main" || basename == "server"), hasLlamaPathComponent(loweredPath) {
            return true
        }
        if loweredCommand.contains(" -m llama_cpp") || loweredPath.contains("/llama_cpp/") {
            return true
        }
        return customTerms.contains { loweredCommand.contains($0) }
    }

    private func hasLlamaPathComponent(_ path: String) -> Bool {
        path.contains("/llama.cpp/") || path.contains("/llama-cpp/")
    }
}
