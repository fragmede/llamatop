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

public struct MemoryStatistics: Equatable, Sendable {
    public let activeBytes: UInt64
    public let inactiveBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let freeBytes: UInt64
    public let pageSizeBytes: UInt64
    public let cacheLineBytes: UInt64?
    public let swapTotalBytes: UInt64?
    public let swapUsedBytes: UInt64?
    public let memoryType: String?
    public let manufacturer: String?

    public init(
        activeBytes: UInt64,
        inactiveBytes: UInt64,
        wiredBytes: UInt64,
        compressedBytes: UInt64,
        freeBytes: UInt64,
        pageSizeBytes: UInt64,
        cacheLineBytes: UInt64?,
        swapTotalBytes: UInt64?,
        swapUsedBytes: UInt64?,
        memoryType: String?,
        manufacturer: String?
    ) {
        self.activeBytes = activeBytes
        self.inactiveBytes = inactiveBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.freeBytes = freeBytes
        self.pageSizeBytes = pageSizeBytes
        self.cacheLineBytes = cacheLineBytes
        self.swapTotalBytes = swapTotalBytes
        self.swapUsedBytes = swapUsedBytes
        self.memoryType = memoryType
        self.manufacturer = manufacturer
    }
}

public struct SystemSnapshot: Equatable, Sendable {
    public let timestamp: Date
    public let machineName: String
    public let systemCPU: SystemCPUStatistics
    public let physicalMemoryBytes: UInt64
    public let memory: MemoryStatistics?
    public let gpu: GPUStatistics?
    public let processes: [MonitoredProcess]

    public init(
        timestamp: Date,
        machineName: String,
        systemCPU: SystemCPUStatistics,
        physicalMemoryBytes: UInt64,
        memory: MemoryStatistics? = nil,
        gpu: GPUStatistics?,
        processes: [MonitoredProcess]
    ) {
        self.timestamp = timestamp
        self.machineName = machineName
        self.systemCPU = systemCPU
        self.physicalMemoryBytes = physicalMemoryBytes
        self.memory = memory
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
