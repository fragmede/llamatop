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

    func waitForKey(timeout: TimeInterval) -> UInt8? {
        var descriptor = pollfd(fd: fileDescriptor, events: Int16(POLLIN), revents: 0)
        let timeoutMilliseconds = Int32(min(
            Double(Int32.max),
            max(0, timeout * 1_000)
        ))

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
}
