import Foundation

public final class LlamaTopMonitor {
    private let processProbe: any ProcessProbing
    private let gpuProbe: any GPUProbing
    private let matcher: LlamaProcessMatcher
    private let environment: any MonitorEnvironment
    private var previousCPUTimeByIdentity: [ProcessIdentity: UInt64] = [:]
    private var previousSampleTicks: UInt64?

    public convenience init(customMatchTerms: [String] = []) {
        self.init(
            processProbe: DarwinProcessProbe(),
            gpuProbe: AppleGPUProbe(),
            matcher: LlamaProcessMatcher(customTerms: customMatchTerms),
            environment: SystemMonitorEnvironment()
        )
    }

    init(
        processProbe: any ProcessProbing,
        gpuProbe: any GPUProbing,
        matcher: LlamaProcessMatcher,
        environment: any MonitorEnvironment
    ) {
        self.processProbe = processProbe
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
            logicalCPUCount: environment.logicalCPUCount,
            physicalMemoryBytes: environment.physicalMemoryBytes,
            gpuPercent: gpuProbe.utilization(),
            processes: processes
        )
    }

}
