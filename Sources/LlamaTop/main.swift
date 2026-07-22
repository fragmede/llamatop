import Darwin
import Foundation
import LlamaTopCore

func terminalWidth(interactive: Bool) -> Int {
    if interactive {
        var size = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0, size.ws_col > 0 {
            return Int(size.ws_col)
        }
    }
    return Int(ProcessInfo.processInfo.environment["COLUMNS"] ?? "") ?? 100
}

do {
    let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
    if options.showHelp {
        print(Options.help)
        exit(EXIT_SUCCESS)
    }
    if options.showVersion {
        print(LlamaTopVersion.displayName)
        exit(EXIT_SUCCESS)
    }

    let interactive = isatty(STDOUT_FILENO) == 1 && !options.once
    let acceptsInput = interactive && isatty(STDIN_FILENO) == 1
    let color = interactive && !options.noColor && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
    let monitor = LlamaTopMonitor(customMatchTerms: options.customMatchTerms)
    let terminalInput = acceptsInput ? TerminalInputSession() : nil
    var displayState = DashboardDisplayState(
        mode: terminalInput == nil ? .detailed : .summary,
        showsMemoryDetails: terminalInput == nil
    )

    if terminalInput != nil {
        installTerminationHandlers()
    }
    defer {
        terminalInput?.restore()
    }

    _ = monitor.nextSnapshot()
    Thread.sleep(forTimeInterval: min(0.25, options.interval))
    var snapshot = monitor.nextSnapshot()

    while !isTerminationRequested() {
        let renderer = DashboardRenderer(color: color, width: terminalWidth(interactive: interactive))
        let dashboard = renderer.render(
            snapshot,
            mode: displayState.mode,
            showMemoryDetails: displayState.showsMemoryDetails
        )
        if interactive {
            print("\u{001B}[2J\u{001B}[H", terminator: "")
        }
        print(dashboard)
        if interactive {
            let detailAction = displayState.mode == .summary ? "show details" : "hide details"
            let memoryAction = displayState.showsMemoryDetails ? "hide memory" : "show memory"
            var controls = "Refresh \(String(format: "%.1fs", options.interval))"
            if terminalInput != nil {
                controls += " · 1: \(detailAction)"
                controls += " · m: \(memoryAction)"
            }
            controls += " · Ctrl-C to quit"
            print("\n\(controls)", terminator: "")
            fflush(stdout)
            let key = terminalInput?.waitForKey(timeout: options.interval)
            if isTerminationRequested() { break }
            if let key, displayState.handle(key: key) {
                continue
            }
            if terminalInput == nil {
                Thread.sleep(forTimeInterval: options.interval)
            }
            snapshot = monitor.nextSnapshot()
        }
        if !interactive { break }
    }
    if interactive {
        print()
    }
} catch let error as OptionsError {
    fputs("llamatop: \(error.description)\nTry 'llamatop --help'.\n", stderr)
    exit(EXIT_FAILURE)
} catch {
    fputs("llamatop: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
