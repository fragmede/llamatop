import Foundation

public struct Options: Equatable, Sendable {
    public var interval: TimeInterval = 1
    public var once = false
    public var noColor = false
    public var customMatchTerms: [String] = []
    public var showHelp = false
    public var showVersion = false

    public init() {}

    public static func parse(_ arguments: [String]) throws -> Options {
        var options = Options()
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--once":
                options.once = true
            case "--no-color":
                options.noColor = true
            case "--help", "-h":
                options.showHelp = true
            case "--version", "-v":
                options.showVersion = true
            case "--interval", "-i":
                index += 1
                guard index < arguments.count, let interval = TimeInterval(arguments[index]) else {
                    throw OptionsError("--interval requires a number of seconds")
                }
                guard RefreshInterval.parse(arguments[index]) != nil else {
                    throw OptionsError("--interval must be between 0.2 and 60 seconds")
                }
                options.interval = interval
            case "--match":
                index += 1
                guard index < arguments.count, !arguments[index].isEmpty else {
                    throw OptionsError("--match requires a command substring")
                }
                options.customMatchTerms.append(arguments[index])
            default:
                throw OptionsError("unknown option: \(arguments[index])")
            }
            index += 1
        }

        return options
    }

    public static let help = """
    \(LlamaTopVersion.displayName) — see whether llama.cpp is actually working on your Mac

    USAGE
      llamatop [options]

    OPTIONS
      -i, --interval SECONDS  Refresh interval (0.2–60; default: 1)
          --once              Print one warmed-up sample and exit
          --match TEXT        Also watch commands containing TEXT (repeatable)
          --no-color          Disable ANSI colors
      -h, --help              Show this help
      -v, --version           Show the version

    LIVE KEYS
      ?/h                     Show all interactive commands
      q                       Quit
      s/d                     Change the refresh interval
      1                       Toggle per-core CPU detail and GPU core inventory
      m                       Toggle system memory layout and hardware details
      P/M/T/N/C               Sort processes by CPU/RAM/time/PID/command
      Ctrl-C                  Quit and restore the terminal

    LlamaTop recognizes llama-* tools, llama.cpp legacy main/server binaries,
    and python -m llama_cpp. Apple GPU utilization is always system-wide;
    the GPU inventory shows detected hardware, not per-core utilization.
    """
}

public struct OptionsError: Error, CustomStringConvertible, Equatable, Sendable {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}
