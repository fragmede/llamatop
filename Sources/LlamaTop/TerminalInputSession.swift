import Darwin
import Foundation

nonisolated(unsafe) private var terminationRequested: sig_atomic_t = 0

private func requestTermination(_: Int32) {
    terminationRequested = 1
}

func installTerminationHandlers() {
    signal(SIGINT, requestTermination)
    signal(SIGTERM, requestTermination)
}

func isTerminationRequested() -> Bool {
    terminationRequested != 0
}

enum ValidatedPromptResponse<Value> {
    case value(Value)
    case invalid
}

final class TerminalInputSession {
    private let fileDescriptor: Int32
    private var originalAttributes: termios
    private var isRestored = false

    init?(fileDescriptor: Int32 = STDIN_FILENO) {
        var originalAttributes = termios()
        guard tcgetattr(fileDescriptor, &originalAttributes) == 0 else { return nil }

        var inputAttributes = originalAttributes
        inputAttributes.c_lflag &= ~tcflag_t(ICANON | ECHO)
        guard tcsetattr(fileDescriptor, TCSANOW, &inputAttributes) == 0 else { return nil }

        self.fileDescriptor = fileDescriptor
        self.originalAttributes = originalAttributes
    }

    deinit {
        restore()
    }

    func restore() {
        guard !isRestored else { return }
        var attributes = originalAttributes
        tcsetattr(fileDescriptor, TCSANOW, &attributes)
        isRestored = true
    }

    func waitForKey(timeout: TimeInterval?) -> UInt8? {
        var descriptor = pollfd(fd: fileDescriptor, events: Int16(POLLIN), revents: 0)
        let timeoutMilliseconds = timeout.map {
            Int32(min(Double(Int32.max), max(0, $0 * 1_000)))
        } ?? -1

        while !isTerminationRequested() {
            let result = poll(&descriptor, 1, timeoutMilliseconds)
            if result == 0 { return nil }
            if result < 0 {
                if errno == EINTR { continue }
                return nil
            }

            var byte: UInt8 = 0
            return read(fileDescriptor, &byte, 1) == 1 ? byte : nil
        }
        return nil
    }

    func readResponse(prompt: String) -> String? {
        print("\n\(prompt)", terminator: "")
        fflush(stdout)

        var bytes: [UInt8] = []
        while !isTerminationRequested() {
            guard let byte = waitForKey(timeout: nil) else { return nil }
            switch byte {
            case 10, 13:
                print()
                return String(decoding: bytes, as: UTF8.self)
            case 3, 4, 7:
                print()
                return nil
            case 8 where !bytes.isEmpty, 127 where !bytes.isEmpty:
                bytes.removeLast()
                fputs("\u{8} \u{8}", stdout)
                fflush(stdout)
            case 21:
                while !bytes.isEmpty {
                    bytes.removeLast()
                    fputs("\u{8} \u{8}", stdout)
                }
                fflush(stdout)
            case 32...126:
                bytes.append(byte)
                fputc(Int32(byte), stdout)
                fflush(stdout)
            default:
                continue
            }
        }
        return nil
    }

    func readValidatedResponse<Value>(
        prompt: String,
        parser: (String) -> Value?
    ) -> ValidatedPromptResponse<Value>? {
        guard let response = readResponse(prompt: prompt) else { return nil }
        let normalized = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard let value = parser(normalized) else { return .invalid }
        return .value(value)
    }
}
