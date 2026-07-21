import Darwin
import Foundation

public final class LlamaTopMonitor {
    private let processProbe: any ProcessProbing
    private let gpuProbe: any GPUProbing
    private let matcher: LlamaProcessMatcher
    private let machineName: String
    private var previousCPUTimeByIdentity: [ProcessIdentity: UInt64] = [:]
    private var previousSampleTicks: UInt64?

    public convenience init(customMatchTerms: [String] = []) {
        self.init(
            processProbe: DarwinProcessProbe(),
            gpuProbe: AppleGPUProbe(),
            matcher: LlamaProcessMatcher(customTerms: customMatchTerms),
            machineName: Self.readMachineName()
        )
    }

    init(
        processProbe: any ProcessProbing,
        gpuProbe: any GPUProbing,
        matcher: LlamaProcessMatcher,
        machineName: String
    ) {
        self.processProbe = processProbe
        self.gpuProbe = gpuProbe
        self.matcher = matcher
        self.machineName = machineName
    }

    public func nextSnapshot() -> SystemSnapshot {
        let now = Date()
        let sampleTicks = mach_absolute_time()
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
                elapsed: Self.formatDuration(raw.elapsedSeconds),
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
            machineName: machineName,
            logicalCPUCount: max(1, ProcessInfo.processInfo.processorCount),
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            gpuPercent: gpuProbe.utilization(),
            processes: processes
        )
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let days = seconds / 86_400
        let hours = seconds % 86_400 / 3_600
        let minutes = seconds % 3_600 / 60
        let remainder = seconds % 60
        if days > 0 {
            return String(format: "%d-%02d:%02d:%02d", days, hours, minutes, remainder)
        }
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private static func readMachineName() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 1 else {
            return "Apple Silicon Mac"
        }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 else {
            return "Apple Silicon Mac"
        }
        let utf8 = bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: utf8, as: UTF8.self)
    }
}
