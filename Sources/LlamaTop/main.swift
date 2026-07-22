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
    let colorAllowed = interactive
        && !options.noColor
        && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
    let monitor = LlamaTopMonitor(customMatchTerms: options.customMatchTerms)
    let terminalInput = acceptsInput ? TerminalInputSession() : nil
    var displayState = DashboardDisplayState(
        mode: terminalInput == nil ? .detailed : .summary,
        showsMemoryDetails: terminalInput == nil,
        colorEnabled: colorAllowed,
        allowsColor: colorAllowed
    )
    var refreshInterval = options.interval
    var notice: String?
    var isRunning = true

    if terminalInput != nil {
        installTerminationHandlers()
    }
    defer {
        terminalInput?.restore()
    }

    _ = monitor.nextSnapshot()
    Thread.sleep(forTimeInterval: min(0.25, options.interval))
    var snapshot = monitor.nextSnapshot()

    while isRunning, !isTerminationRequested() {
        let renderer = DashboardRenderer(
            color: displayState.colorEnabled,
            width: terminalWidth(interactive: interactive)
        )
        let dashboard = displayState.showsHelp
            ? renderer.renderHelp(state: displayState, refreshInterval: refreshInterval)
            : renderer.render(snapshot, state: displayState)
        if interactive {
            print("\u{001B}[2J\u{001B}[H", terminator: "")
        }
        print(dashboard)
        if interactive {
            if let message = notice {
                print("\n\(message)", terminator: "")
                notice = nil
            }
            if !displayState.showsHelp {
                var controls = "Refresh \(String(format: "%.1fs", refreshInterval))"
                if terminalInput != nil {
                    controls += " · ?: help · q: quit"
                }
                controls += " · Ctrl-C to quit"
                print("\n\(controls)", terminator: "")
            }
            fflush(stdout)
            let key = terminalInput?.waitForKey(
                timeout: displayState.showsHelp ? nil : refreshInterval
            )
            if isTerminationRequested() { break }
            if terminalInput == nil {
                Thread.sleep(forTimeInterval: refreshInterval)
                snapshot = monitor.nextSnapshot()
                continue
            }
            guard let key else {
                snapshot = monitor.nextSnapshot()
                continue
            }

            switch displayState.action(for: key) {
            case .none, .redraw:
                continue
            case .refresh:
                snapshot = monitor.nextSnapshot()
                continue
            case .quit:
                isRunning = false
            case .promptRefreshInterval:
                let prompt = "Refresh seconds [\(String(format: "%.1f", refreshInterval))]: "
                switch terminalInput?.readValidatedResponse(
                    prompt: prompt,
                    parser: RefreshInterval.parse
                ) {
                case let .value(interval):
                    refreshInterval = interval
                    notice = "Refresh interval set to \(String(format: "%.1fs", interval))."
                case .invalid:
                    notice = "Refresh interval must be between 0.2 and 60 seconds."
                case nil:
                    break
                }
                continue
            case .promptProcessLimit:
                switch terminalInput?.readValidatedResponse(
                    prompt: "Maximum process rows (0 for all): ",
                    parser: ProcessCountLimit.parse
                ) {
                case let .value(limit):
                    displayState.setProcessLimit(limit)
                    notice = "Process row limit updated."
                case .invalid:
                    notice = "Process row limit must be a non-negative integer."
                case nil:
                    break
                }
                continue
            case .promptSort:
                switch terminalInput?.readValidatedResponse(
                    prompt: "Sort by cpu, ram, time, pid, or command: ",
                    parser: ProcessSortKey.parse
                ) {
                case let .value(sortKey):
                    displayState.selectSort(sortKey)
                    notice = "Process sort updated."
                case .invalid:
                    notice = "Unknown sort field. Use cpu, ram, time, pid, or command."
                case nil:
                    break
                }
                continue
            }
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
