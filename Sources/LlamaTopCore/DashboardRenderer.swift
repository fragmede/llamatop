import Foundation

public struct DashboardRenderer: Sendable {
    private let color: Bool
    private let width: Int

    public init(color: Bool, width: Int) {
        self.color = color
        self.width = min(200, max(60, width))
    }

    public func render(
        _ snapshot: SystemSnapshot,
        mode: DashboardMode = .detailed,
        showMemoryDetails: Bool = false
    ) -> String {
        render(
            snapshot,
            state: DashboardDisplayState(
                mode: mode,
                showsMemoryDetails: showMemoryDetails
            )
        )
    }

    public func render(
        _ snapshot: SystemSnapshot,
        state: DashboardDisplayState
    ) -> String {
        let mode = state.mode
        let showMemoryDetails = state.showsMemoryDetails
        let processCount = snapshot.processes.count
        let coreCount = max(1, snapshot.systemCPU.cores.count)
        let normalizedLlamaCPU = snapshot.totalCPUPercent / (Double(coreCount) * 100) * 100
        let llamaCPUValue = snapshot.processes.contains { $0.cpuPercent == nil }
            ? "warming up"
            : String(
                format: "%.1f%%  ≈ %.1f / %d cores",
                snapshot.totalCPUPercent,
                snapshot.totalCPUPercent / 100,
                coreCount
            )
        let llamaMemoryPercent = percentage(
            numerator: snapshot.totalResidentBytes,
            denominator: snapshot.physicalMemoryBytes
        )

        var lines = [
            header(machineName: snapshot.machineName),
            statusLine(state: snapshot.activity, processCount: processCount),
            "",
            "Llama workload (llama.cpp-only)",
            metricLine(label: "CPU", percent: normalizedLlamaCPU, value: llamaCPUValue),
            metricLine(
                label: "RAM",
                percent: llamaMemoryPercent,
                value: "\(bytes(snapshot.totalResidentBytes)) / \(bytes(snapshot.physicalMemoryBytes)) physical"
            ),
        ]
        if showMemoryDetails {
            lines.append("")
            lines.append(contentsOf: memoryLines(
                snapshot.memory,
                physicalMemoryBytes: snapshot.physicalMemoryBytes
            ))
        }
        lines.append("")
        lines.append(cpuHeading(snapshot.systemCPU))
        lines.append(metricLine(
            label: "Total",
            percent: snapshot.systemCPU.averagePercent,
            value: percentValue(snapshot.systemCPU.averagePercent)
        ))
        if mode == .detailed {
            lines.append(contentsOf: coreGrid(snapshot.systemCPU.cores))
        }
        lines.append("")
        lines.append(contentsOf: gpuLines(
            snapshot.gpu,
            physicalMemoryBytes: snapshot.physicalMemoryBytes,
            mode: mode
        ))
        lines.append("")

        let displayedProcesses = processesForDisplay(snapshot.processes, state: state)
        if snapshot.processes.isEmpty {
            lines.append("No llama.cpp process found.")
            lines.append("For renamed wrappers, try --match TEXT.")
        } else {
            lines.append(processViewHeading(
                displayedCount: displayedProcesses.count,
                totalCount: snapshot.processes.count,
                state: state
            ))
            if displayedProcesses.isEmpty {
                lines.append("No processes match the current view.")
            } else {
                lines.append(processHeader(showsFullCommand: state.showsFullCommand))
                lines.append(contentsOf: displayedProcesses.map {
                    processLine($0, showsFullCommand: state.showsFullCommand)
                })
            }
        }

        lines.append("")
        lines.append("Core and GPU bars are system-wide.")
        lines.append("Llama CPU and RAM are llama.cpp-only.")
        lines.append("GPU pipelines are not separate GPUs or additive.")
        if showMemoryDetails {
            lines.append("Memory bars are system-wide VM categories.")
        }
        return lines.joined(separator: "\n")
    }

    public func renderHelp(
        state: DashboardDisplayState,
        refreshInterval: TimeInterval
    ) -> String {
        let direction = state.sortDescending ? "descending" : "ascending"
        let lines = [
            styled("LLAMATOP HELP", code: "1;36"),
            "",
            "Global",
            "  ?/h       Show this help; any other key returns",
            "  q         Quit",
            "  s/d       Change refresh delay (0.2–60 seconds)",
            "            Backspace delete · Ctrl-U clear",
            "            Enter apply · Ctrl-G/Ctrl-D cancel",
            "            Ctrl-C quits LlamaTop",
            "  Space/↵   Refresh now",
            "  Ctrl-L    Redraw the current sample",
            "",
            "Summary",
            "  1         Toggle CPU/GPU detail",
            "  m         Toggle memory layout",
            "",
            "Processes",
            "  P/M/T/N/C Sort by CPU/RAM/time/PID/command",
            "  o         Prompt for a sort field",
            "  R         Reverse sort direction",
            "  c         Toggle full command / executable name",
            "  i         Hide/show known-idle processes",
            "  n/#       Limit process rows (0 means all)",
            "  =         Clear idle filter and row limit",
            "  z         Toggle color when color is allowed",
            "",
            "Current: \(String(format: "%.1fs", refreshInterval)) · "
                + "\(state.processSortKey.displayName) \(direction) · "
                + state.processLimit.displayName,
            "",
            "Not applicable or intentionally omitted",
            "  kill/renice and signal commands (destructive)",
            "  user/thread views (not collected by LlamaTop)",
            "  field editor, multi-window, scrolling/search, config",
            "",
            "Press any other key to return.",
        ]
        return lines.map { truncated($0, to: width) }.joined(separator: "\n")
    }

    private func header(machineName: String) -> String {
        let prefix = "LLAMATOP  "
        let name = truncated(machineName, to: max(1, width - prefix.count))
        return styled("LLAMATOP", code: "1;36") + "  " + name
    }

    private func statusLine(state: ActivityState, processCount: Int) -> String {
        let noun = processCount == 1 ? "process" : "processes"
        let plainSuffix = "  \(processCount) llama.cpp \(noun)"
        return styled(state.rawValue, code: stateColor(state)) + plainSuffix
    }

    private func cpuHeading(_ statistics: SystemCPUStatistics) -> String {
        var topology: [String] = []
        if let performance = statistics.performanceCoreCount {
            topology.append("\(performance)P")
        }
        if let efficiency = statistics.efficiencyCoreCount {
            topology.append("\(efficiency)E")
        }
        let suffix = topology.isEmpty ? "" : " · \(topology.joined(separator: " + "))"
        return "CPU logical cores (system-wide\(suffix))"
    }

    private func coreGrid(_ cores: [CPUCoreUsage]) -> [String] {
        guard !cores.isEmpty else { return ["Core utilization unavailable"] }
        let columns = max(1, (width + 2) / 20)
        return stride(from: 0, to: cores.count, by: columns).map { start in
            let end = min(start + columns, cores.count)
            return cores[start..<end].map(coreCell).joined(separator: "  ")
        }
    }

    private func coreCell(_ core: CPUCoreUsage) -> String {
        let value = core.percent.map { String(format: "%3.0f%%", clamped($0)) } ?? " --%"
        return String(format: "C%02d", core.index) + " " + bar(core.percent, length: 7) + " " + value
    }

    private func memoryLines(
        _ statistics: MemoryStatistics?,
        physicalMemoryBytes: UInt64
    ) -> [String] {
        var heading = "Memory layout (system-wide · unified"
        if let memoryType = statistics?.memoryType, !memoryType.isEmpty {
            heading += " · \(memoryType)"
        }
        heading += ")"

        guard let statistics else {
            return [
                truncated(heading, to: width),
                "Memory telemetry unavailable",
                "Banks/channels unavailable through macOS",
            ]
        }

        let categories: [(label: String, byteCount: UInt64)] = [
            ("Wired", statistics.wiredBytes),
            ("Active", statistics.activeBytes),
            ("Inactive", statistics.inactiveBytes),
            ("Compressed", statistics.compressedBytes),
            ("Free", statistics.freeBytes),
        ]
        let accountedBytes = categories.reduce(UInt64(0)) { partial, category in
            let result = partial.addingReportingOverflow(category.byteCount)
            return result.overflow ? UInt64.max : result.partialValue
        }
        let otherBytes = physicalMemoryBytes > accountedBytes
            ? physicalMemoryBytes - accountedBytes
            : 0

        var lines = [truncated(heading, to: width)]
        for category in categories + [("Other", otherBytes)] {
            lines.append(metricLine(
                label: category.label,
                percent: percentage(
                    numerator: category.byteCount,
                    denominator: physicalMemoryBytes
                ),
                value: bytes(category.byteCount)
            ))
        }
        if let swapTotal = statistics.swapTotalBytes,
           let swapUsed = statistics.swapUsedBytes {
            lines.append(metricLine(
                label: "Swap",
                percent: percentage(numerator: swapUsed, denominator: swapTotal),
                value: "\(bytes(swapUsed)) / \(bytes(swapTotal))"
            ))
        }

        var hardware = "\(bytes(physicalMemoryBytes))"
        if let memoryType = statistics.memoryType, !memoryType.isEmpty {
            hardware += " \(memoryType)"
        }
        hardware += " unified"
        if let manufacturer = statistics.manufacturer, !manufacturer.isEmpty {
            hardware += " · \(manufacturer)"
        }
        lines.append(truncated("Hardware   \(hardware)", to: width))

        var pageDetails = "\(bytes(statistics.pageSizeBytes)) pages"
        if let cacheLineBytes = statistics.cacheLineBytes {
            pageDetails += " · \(bytes(cacheLineBytes)) cache line"
        }
        lines.append(truncated("Geometry   \(pageDetails)", to: width))
        lines.append("Banks/channels unavailable through macOS")
        return lines
    }

    private func gpuLines(
        _ statistics: GPUStatistics?,
        physicalMemoryBytes: UInt64,
        mode: DashboardMode
    ) -> [String] {
        var heading: String
        if let coreCount = statistics?.coreCount {
            heading = "Apple GPU (\(coreCount) cores · system-wide)"
        } else {
            heading = "Apple GPU activity (system-wide)"
        }
        if let model = statistics?.model, !model.isEmpty {
            heading += " · \(model)"
        }

        var lines = [truncated(heading, to: width)]
        let pipelines: [(label: String, percent: Double?, alwaysVisible: Bool)] = [
            ("Device", statistics?.devicePercent, true),
            ("Renderer", statistics?.rendererPercent, false),
            ("Tiler", statistics?.tilerPercent, false),
        ]
        for pipeline in pipelines
        where pipeline.alwaysVisible || (mode == .detailed && pipeline.percent != nil) {
            lines.append(metricLine(
                label: pipeline.label,
                percent: pipeline.percent,
                value: percentValue(pipeline.percent)
            ))
        }
        if let inUse = statistics?.inUseSystemMemoryBytes
            ?? statistics?.allocatedSystemMemoryBytes {
            let value = gpuMemoryValue(
                inUseBytes: statistics?.inUseSystemMemoryBytes,
                allocatedBytes: statistics?.allocatedSystemMemoryBytes
            )
            lines.append(metricLine(
                label: "GPU Memory",
                percent: percentage(numerator: inUse, denominator: physicalMemoryBytes),
                value: value
            ))
        }
        if mode == .detailed, let coreCount = statistics?.coreCount, coreCount > 0 {
            lines.append("")
            lines.append(contentsOf: gpuCoreInventory(coreCount))
        }
        return lines
    }

    private func gpuCoreInventory(_ coreCount: Int) -> [String] {
        let groups = stride(from: 0, to: coreCount, by: 10).map { start in
            String(repeating: "◆", count: min(10, coreCount - start))
        }
        let symbolLines = stride(from: 0, to: groups.count, by: 4).map { start in
            let prefix = start == 0 ? "Cores " : "      "
            return prefix + groups[start..<min(start + 4, groups.count)].joined(separator: " ")
        }
        return ["GPU cores (presence only; no per-core telemetry)"]
            + symbolLines
            + ["\(coreCount) detected · activity is aggregate"]
    }

    private func gpuMemoryValue(inUseBytes: UInt64?, allocatedBytes: UInt64?) -> String {
        var parts: [String] = []
        if let inUseBytes { parts.append("\(bytes(inUseBytes)) in use") }
        if let allocatedBytes { parts.append("\(bytes(allocatedBytes)) allocated") }
        return parts.joined(separator: " · ")
    }

    private func percentValue(_ percent: Double?) -> String {
        percent.map { String(format: "%.1f%% system-wide", clamped($0)) } ?? "unavailable"
    }

    private func processViewHeading(
        displayedCount: Int,
        totalCount: Int,
        state: DashboardDisplayState
    ) -> String {
        let direction = state.sortDescending ? "↓" : "↑"
        let commandMode = state.showsFullCommand ? "command" : "name"
        let idleMode = state.hidesIdleProcesses ? "active only" : "idle shown"
        return truncated(
            "Processes \(displayedCount)/\(totalCount) · "
                + "\(state.processSortKey.displayName)\(direction) · "
                + "\(commandMode) · \(idleMode) · \(state.processLimit.displayName)",
            to: width
        )
    }

    private func processHeader(showsFullCommand: Bool) -> String {
        "   PID    CPU       RAM       TIME  " + (showsFullCommand ? "COMMAND" : "NAME")
    }

    private func processLine(
        _ process: MonitoredProcess,
        showsFullCommand: Bool
    ) -> String {
        let cpu = process.cpuPercent.map { String(format: "%6.1f%%", $0) } ?? " warmup"
        let prefix = String(
            format: "%6d %@ %9@ %10@  ",
            process.pid,
            cpu,
            bytes(process.residentBytes),
            duration(process.elapsedSeconds)
        )
        let executableName = URL(fileURLWithPath: process.executable).lastPathComponent
        let displayedCommand = showsFullCommand ? process.command : executableName
        return prefix + truncated(displayedCommand, to: max(1, width - prefix.count))
    }

    private func processesForDisplay(
        _ processes: [MonitoredProcess],
        state: DashboardDisplayState
    ) -> [MonitoredProcess] {
        var result = state.hidesIdleProcesses
            ? processes.filter { !ActivityClassifier.isKnownIdle($0) }
            : processes
        result.sort { left, right in
            let comparison = compare(left, right, by: state.processSortKey)
            if comparison == .orderedSame { return left.pid < right.pid }
            return state.sortDescending
                ? comparison == .orderedDescending
                : comparison == .orderedAscending
        }
        if let maximum = state.processLimit.maximum {
            result = Array(result.prefix(maximum))
        }
        return result
    }

    private func compare(
        _ left: MonitoredProcess,
        _ right: MonitoredProcess,
        by key: ProcessSortKey
    ) -> ComparisonResult {
        switch key {
        case .cpu:
            compare(left.cpuPercent ?? -1, right.cpuPercent ?? -1)
        case .memory:
            compare(left.residentBytes, right.residentBytes)
        case .elapsedTime:
            compare(left.elapsedSeconds, right.elapsedSeconds)
        case .pid:
            compare(left.pid, right.pid)
        case .command:
            left.command.localizedCaseInsensitiveCompare(right.command)
        }
    }

    private func compare<Value: Comparable>(
        _ left: Value,
        _ right: Value
    ) -> ComparisonResult {
        if left < right { return .orderedAscending }
        if left > right { return .orderedDescending }
        return .orderedSame
    }

    private func metricLine(label: String, percent: Double?, value: String) -> String {
        let labelWidth = 10
        let labelField = truncated(label, to: labelWidth)
            .padding(toLength: labelWidth, withPad: " ", startingAt: 0)
        let maxValueLength = max(1, width - labelWidth - 11)
        let fittedValue = truncated(value, to: maxValueLength)
        let barLength = min(40, max(6, width - labelWidth - 5 - fittedValue.count))
        return "\(labelField) \(bar(percent, length: barLength))  \(fittedValue)"
    }

    private func bar(_ percent: Double?, length: Int) -> String {
        guard let percent else { return "[\(String(repeating: "·", count: length))]" }
        let filled = Int((clamped(percent) / 100 * Double(length)).rounded())
        let active = styled(String(repeating: "█", count: filled), code: "32")
        return "[\(active)\(String(repeating: "░", count: length - filled))]"
    }

    private func stateColor(_ state: ActivityState) -> String {
        switch state {
        case .busy: "1;32"
        case .idle: "1;33"
        case .warmingUp: "1;36"
        case .notFound: "1;31"
        }
    }

    private func styled(_ value: String, code: String) -> String {
        color ? "\u{001B}[\(code)m\(value)\u{001B}[0m" : value
    }

    private func clamped(_ percent: Double) -> Double {
        min(100, max(0, percent))
    }

    private func percentage(numerator: UInt64, denominator: UInt64) -> Double? {
        guard denominator > 0 else { return nil }
        return Double(numerator) / Double(denominator) * 100
    }

    private func bytes(_ value: UInt64) -> String {
        let units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var amount = Double(value)
        var unit = 0
        while amount >= 1_024, unit < units.count - 1 {
            amount /= 1_024
            unit += 1
        }
        return unit == 0 ? "\(value) B" : String(format: "%.1f %@", amount, units[unit])
    }

    private func duration(_ interval: TimeInterval) -> String {
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

    private func truncated(_ value: String, to length: Int) -> String {
        guard value.count > length else { return value }
        guard length > 1 else { return "…" }
        return String(value.prefix(length - 1)) + "…"
    }
}
