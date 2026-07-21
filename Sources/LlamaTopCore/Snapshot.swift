import Foundation

public struct MonitoredProcess: Equatable, Sendable {
    public let pid: Int32
    public let parentPID: Int32
    public let cpuPercent: Double?
    public let residentBytes: UInt64
    public let elapsed: String
    public let executable: String
    public let command: String

    public init(
        pid: Int32,
        parentPID: Int32,
        cpuPercent: Double?,
        residentBytes: UInt64,
        elapsed: String,
        executable: String,
        command: String
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.cpuPercent = cpuPercent
        self.residentBytes = residentBytes
        self.elapsed = elapsed
        self.executable = executable
        self.command = command
    }
}

public struct SystemSnapshot: Equatable, Sendable {
    public let timestamp: Date
    public let machineName: String
    public let logicalCPUCount: Int
    public let physicalMemoryBytes: UInt64
    public let gpuPercent: Double?
    public let processes: [MonitoredProcess]

    public init(
        timestamp: Date,
        machineName: String,
        logicalCPUCount: Int,
        physicalMemoryBytes: UInt64,
        gpuPercent: Double?,
        processes: [MonitoredProcess]
    ) {
        self.timestamp = timestamp
        self.machineName = machineName
        self.logicalCPUCount = logicalCPUCount
        self.physicalMemoryBytes = physicalMemoryBytes
        self.gpuPercent = gpuPercent
        self.processes = processes
    }

    public var totalCPUPercent: Double {
        processes.compactMap(\.cpuPercent).reduce(0, +)
    }

    public var totalResidentBytes: UInt64 {
        processes.reduce(0) { partial, process in
            let result = partial.addingReportingOverflow(process.residentBytes)
            return result.overflow ? UInt64.max : result.partialValue
        }
    }

    public var activity: ActivityState {
        ActivityClassifier.classify(processes: processes, gpuPercent: gpuPercent)
    }
}

public enum ActivityState: String, Equatable, Sendable {
    case busy = "BUSY"
    case idle = "IDLE"
    case notFound = "NOT FOUND"
}
