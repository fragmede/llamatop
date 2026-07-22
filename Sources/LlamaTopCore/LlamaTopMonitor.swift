import Foundation

public final class LlamaTopMonitor {
    private let processProbe: any ProcessProbing
    private let cpuProbe: any CPUCoreProbing
    private let memoryProbe: any MemoryProbing
    private let gpuProbe: any GPUProbing
    private let matcher: LlamaProcessMatcher
    private let environment: any MonitorEnvironment
    private var previousCPUTimeByIdentity: [ProcessIdentity: UInt64] = [:]
    private var previousSampleTicks: UInt64?
    private var previousCoreTicks: [CPUCoreTicks]?

    public convenience init(customMatchTerms: [String] = []) {
        self.init(
            processProbe: DarwinProcessProbe(),
            cpuProbe: DarwinCPUCoreProbe(),
            memoryProbe: DarwinMemoryProbe(),
            gpuProbe: AppleGPUProbe(),
            matcher: LlamaProcessMatcher(customTerms: customMatchTerms),
            environment: SystemMonitorEnvironment()
        )
    }

    init(
        processProbe: any ProcessProbing,
        cpuProbe: any CPUCoreProbing,
        memoryProbe: any MemoryProbing,
        gpuProbe: any GPUProbing,
        matcher: LlamaProcessMatcher,
        environment: any MonitorEnvironment
    ) {
        self.processProbe = processProbe
        self.cpuProbe = cpuProbe
        self.memoryProbe = memoryProbe
        self.gpuProbe = gpuProbe
        self.matcher = matcher
        self.environment = environment
    }

    public func nextSnapshot() -> SystemSnapshot {
        let now = environment.currentDate()
        let sampleTicks = environment.currentUptimeTicks()
        let elapsed = previousSampleTicks.map { previous in
            sampleTicks >= previous ? sampleTicks - previous : 0
        } ?? 0
        let rawProcesses = processProbe.capture(at: now).filter {
            matcher.matches(executable: $0.executable, command: $0.command)
        }
        let corePercentages: [Double?]
        if let currentCoreTicks = cpuProbe.capture() {
            corePercentages = CPUCoreUsageCalculator.percentages(
                previous: previousCoreTicks,
                current: currentCoreTicks
            )
            previousCoreTicks = currentCoreTicks
        } else {
            corePercentages = Array(repeating: nil, count: environment.logicalCPUCount)
        }

        let processes = rawProcesses.map { raw in
            MonitoredProcess(
                pid: raw.identity.pid,
                parentPID: raw.parentPID,
                cpuPercent: CPUUsageCalculator.percent(
                    previousCPUTimeTicks: previousCPUTimeByIdentity[raw.identity],
                    currentCPUTimeTicks: raw.totalCPUTimeTicks,
                    elapsedTicks: elapsed
                ),
                residentBytes: raw.residentBytes,
                elapsedSeconds: raw.elapsedSeconds,
                executable: raw.executable,
                command: raw.command
            )
        }.sorted { left, right in
            let leftCPU = left.cpuPercent ?? -1
            let rightCPU = right.cpuPercent ?? -1
            if leftCPU != rightCPU { return leftCPU > rightCPU }
            if left.residentBytes != right.residentBytes {
                return left.residentBytes > right.residentBytes
            }
            return left.pid < right.pid
        }

        previousCPUTimeByIdentity = Dictionary(
            uniqueKeysWithValues: rawProcesses.map { ($0.identity, $0.totalCPUTimeTicks) }
        )
        previousSampleTicks = sampleTicks

        return SystemSnapshot(
            timestamp: now,
            machineName: environment.machineName,
            systemCPU: SystemCPUStatistics(
                cores: corePercentages.enumerated().map {
                    CPUCoreUsage(index: $0.offset, percent: $0.element)
                },
                performanceCoreCount: environment.performanceCoreCount,
                efficiencyCoreCount: environment.efficiencyCoreCount
            ),
            physicalMemoryBytes: environment.physicalMemoryBytes,
            memory: memoryProbe.capture(),
            gpu: gpuProbe.capture(),
            processes: processes
        )
    }

}
