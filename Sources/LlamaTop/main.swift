import Darwin
import Foundation
import LlamaTopCore

do {
    let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
    if options.showHelp {
        print(Options.help)
        exit(EXIT_SUCCESS)
    }
    if options.showVersion {
        print("LlamaTop 0.1.0")
        exit(EXIT_SUCCESS)
    }

    let interactive = isatty(STDOUT_FILENO) == 1 && !options.once
    let color = interactive && !options.noColor && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
    let width = Int(ProcessInfo.processInfo.environment["COLUMNS"] ?? "") ?? 100
    let renderer = DashboardRenderer(color: color, width: width)
    let monitor = LlamaTopMonitor(customMatchTerms: options.customMatchTerms)

    _ = monitor.nextSnapshot()
    Thread.sleep(forTimeInterval: min(0.25, options.interval))

    repeat {
        let dashboard = renderer.render(monitor.nextSnapshot())
        if interactive {
            print("\u{001B}[2J\u{001B}[H", terminator: "")
        }
        print(dashboard)
        if interactive {
            print("\nRefresh \(String(format: "%.1fs", options.interval)) · Ctrl-C to quit", terminator: "")
            fflush(stdout)
            Thread.sleep(forTimeInterval: options.interval)
        }
    } while interactive
} catch let error as OptionsError {
    fputs("llamatop: \(error.description)\nTry 'llamatop --help'.\n", stderr)
    exit(EXIT_FAILURE)
} catch {
    fputs("llamatop: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
