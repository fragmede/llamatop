import Foundation

public enum CommandSanitizer {
    private static let secretFlags = Set([
        "--access-token",
        "--api-key",
        "--hf-token",
        "--token",
    ])

    public static func display(arguments: [String]) -> String {
        var output: [String] = []
        var shouldRedactNext = false

        for argument in arguments {
            let cleaned = removeControlCharacters(from: argument)
            let lowered = cleaned.lowercased()

            if shouldRedactNext {
                output.append("••••")
                shouldRedactNext = false
                continue
            }

            if secretFlags.contains(lowered) {
                output.append(quoteIfNeeded(cleaned))
                shouldRedactNext = true
                continue
            }

            if let flag = secretFlags.first(where: { lowered.hasPrefix($0 + "=") }) {
                output.append("\(flag)=••••")
                continue
            }

            output.append(quoteIfNeeded(cleaned))
        }

        return output.joined(separator: " ")
    }

    private static func removeControlCharacters(from value: String) -> String {
        String(value.unicodeScalars.map { scalar in
            CharacterSet.controlCharacters.contains(scalar) ? " " : Character(scalar)
        })
    }

    private static func quoteIfNeeded(_ value: String) -> String {
        guard value.contains(where: \Character.isWhitespace) else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
