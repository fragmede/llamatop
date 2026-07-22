import Foundation

public enum DashboardMode: Equatable, Sendable {
    case summary
    case detailed

    public mutating func toggle() {
        self = self == .summary ? .detailed : .summary
    }
}

public enum DashboardAction: Equatable, Sendable {
    case none
    case redraw
    case refresh
    case promptRefreshInterval
    case promptProcessLimit
    case promptSort
    case quit
}

public enum ProcessSortKey: String, Equatable, Sendable {
    case cpu
    case memory
    case elapsedTime
    case pid
    case command

    public static func parse(_ value: String) -> ProcessSortKey? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "cpu", "p": .cpu
        case "memory", "mem", "ram", "m": .memory
        case "elapsed", "time", "t": .elapsedTime
        case "pid", "n": .pid
        case "command", "cmd", "c": .command
        default: nil
        }
    }

    var displayName: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "RAM"
        case .elapsedTime: "TIME"
        case .pid: "PID"
        case .command: "COMMAND"
        }
    }
}

public enum ProcessCountLimit: Equatable, Sendable {
    case unlimited
    case maximum(Int)

    public static func parse(_ value: String) -> ProcessCountLimit? {
        guard let count = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              count >= 0 else {
            return nil
        }
        return count == 0 ? .unlimited : .maximum(count)
    }

    var maximum: Int? {
        switch self {
        case .unlimited: nil
        case let .maximum(count): count
        }
    }

    var displayName: String {
        switch self {
        case .unlimited: "all"
        case let .maximum(count): "top \(count)"
        }
    }
}

public enum RefreshInterval {
    public static let minimum: TimeInterval = 0.2
    public static let maximum: TimeInterval = 60

    public static func parse(_ value: String) -> TimeInterval? {
        guard let interval = TimeInterval(
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        ),
        interval >= minimum,
        interval <= maximum else {
            return nil
        }
        return interval
    }
}

public struct DashboardDisplayState: Equatable, Sendable {
    public private(set) var mode: DashboardMode
    public private(set) var showsMemoryDetails: Bool
    public private(set) var processSortKey: ProcessSortKey
    public private(set) var sortDescending: Bool
    public private(set) var showsFullCommand: Bool
    public private(set) var hidesIdleProcesses: Bool
    public private(set) var processLimit: ProcessCountLimit
    public private(set) var showsHelp: Bool
    public private(set) var colorEnabled: Bool
    private let allowsColor: Bool

    public init(
        mode: DashboardMode,
        showsMemoryDetails: Bool,
        colorEnabled: Bool = false,
        allowsColor: Bool = false
    ) {
        self.mode = mode
        self.showsMemoryDetails = showsMemoryDetails
        processSortKey = .cpu
        sortDescending = true
        showsFullCommand = true
        hidesIdleProcesses = false
        processLimit = .unlimited
        showsHelp = false
        self.allowsColor = allowsColor
        self.colorEnabled = allowsColor && colorEnabled
    }

    @discardableResult
    public mutating func handle(key: UInt8) -> Bool {
        switch key {
        case UInt8(ascii: "1"):
            mode.toggle()
        case UInt8(ascii: "m"), UInt8(ascii: "M"):
            showsMemoryDetails.toggle()
        default:
            return false
        }
        return true
    }

    public mutating func action(for key: UInt8) -> DashboardAction {
        if showsHelp {
            showsHelp = false
            return key == UInt8(ascii: "q") ? .quit : .redraw
        }

        switch key {
        case UInt8(ascii: "1"), UInt8(ascii: "m"):
            _ = handle(key: key)
        case UInt8(ascii: "?"), UInt8(ascii: "h"):
            showsHelp = true
        case UInt8(ascii: "s"), UInt8(ascii: "d"):
            return .promptRefreshInterval
        case UInt8(ascii: "n"), UInt8(ascii: "#"):
            return .promptProcessLimit
        case UInt8(ascii: "o"):
            return .promptSort
        case UInt8(ascii: "q"):
            return .quit
        case UInt8(ascii: " "), 10, 13:
            return .refresh
        case 12:
            return .redraw
        case UInt8(ascii: "P"):
            selectSort(.cpu)
        case UInt8(ascii: "M"):
            selectSort(.memory)
        case UInt8(ascii: "T"):
            selectSort(.elapsedTime)
        case UInt8(ascii: "N"):
            selectSort(.pid)
        case UInt8(ascii: "C"):
            selectSort(.command)
        case UInt8(ascii: "R"):
            sortDescending.toggle()
        case UInt8(ascii: "c"):
            showsFullCommand.toggle()
        case UInt8(ascii: "i"):
            hidesIdleProcesses.toggle()
        case UInt8(ascii: "z") where allowsColor:
            colorEnabled.toggle()
        case UInt8(ascii: "="):
            hidesIdleProcesses = false
            processLimit = .unlimited
        default:
            return .none
        }
        return .redraw
    }

    public mutating func setProcessLimit(_ limit: ProcessCountLimit) {
        processLimit = limit
    }

    public mutating func selectSort(_ key: ProcessSortKey) {
        processSortKey = key
        sortDescending = true
    }
}
