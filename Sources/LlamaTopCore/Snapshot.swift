import Foundation

public struct MonitoredProcess: Equatable, Sendable {
    public let pid: Int32
    public let parentPID: Int32
    public let cpuPercent: Double?
    public let residentBytes: UInt64
    public let elapsedSeconds: TimeInterval
    public let executable: String
    public let command: String

    public init(
        pid: Int32,
        parentPID: Int32,
        cpuPercent: Double?,
        residentBytes: UInt64,
        elapsedSeconds: TimeInterval,
        executable: String,
        command: String
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.cpuPercent = cpuPercent
        self.residentBytes = residentBytes
        self.elapsedSeconds = elapsedSeconds
        self.executable = executable
        self.command = command
    }
}

public struct CPUCoreUsage: Equatable, Sendable {
    public let index: Int
    public let percent: Double?

    public init(index: Int, percent: Double?) {
        self.index = index
        self.percent = percent
    }
}

public struct SystemCPUStatistics: Equatable, Sendable {
    public let cores: [CPUCoreUsage]
    public let performanceCoreCount: Int?
    public let efficiencyCoreCount: Int?

    public init(
        cores: [CPUCoreUsage],
        performanceCoreCount: Int?,
        efficiencyCoreCount: Int?
    ) {
        self.cores = cores
        self.performanceCoreCount = performanceCoreCount
        self.efficiencyCoreCount = efficiencyCoreCount
    }

    public var averagePercent: Double? {
        let known = cores.compactMap(\.percent)
        guard !known.isEmpty else { return nil }
        return known.reduce(0, +) / Double(known.count)
    }
}

public struct GPUStatistics: Equatable, Sendable {
    public let model: String?
    public let coreCount: Int?
    public let devicePercent: Double?
    public let rendererPercent: Double?
    public let tilerPercent: Double?
    public let allocatedSystemMemoryBytes: UInt64?
    public let inUseSystemMemoryBytes: UInt64?

    public init(
        model: String?,
        coreCount: Int?,
        devicePercent: Double?,
        rendererPercent: Double?,
        tilerPercent: Double?,
        allocatedSystemMemoryBytes: UInt64?,
        inUseSystemMemoryBytes: UInt64?
    ) {
        self.model = model
        self.coreCount = coreCount
        self.devicePercent = devicePercent
        self.rendererPercent = rendererPercent
        self.tilerPercent = tilerPercent
        self.allocatedSystemMemoryBytes = allocatedSystemMemoryBytes
        self.inUseSystemMemoryBytes = inUseSystemMemoryBytes
    }
}

public struct SystemSnapshot: Equatable, Sendable {
    public let timestamp: Date
    public let machineName: String
    public let systemCPU: SystemCPUStatistics
    public let physicalMemoryBytes: UInt64
    public let gpu: GPUStatistics?
    public let processes: [MonitoredProcess]

    public init(
        timestamp: Date,
        machineName: String,
        systemCPU: SystemCPUStatistics,
        physicalMemoryBytes: UInt64,
        gpu: GPUStatistics?,
        processes: [MonitoredProcess]
    ) {
        self.timestamp = timestamp
        self.machineName = machineName
        self.systemCPU = systemCPU
        self.physicalMemoryBytes = physicalMemoryBytes
        self.gpu = gpu
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
        ActivityClassifier.classify(processes: processes)
    }
}

public enum ActivityState: String, Equatable, Sendable {
    case busy = "BUSY"
    case idle = "IDLE"
    case warmingUp = "WARMING UP"
    case notFound = "NOT FOUND"
}
