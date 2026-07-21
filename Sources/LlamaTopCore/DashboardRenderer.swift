import Foundation

public struct DashboardRenderer: Sendable {
    private let color: Bool
    private let width: Int

    public init(color: Bool, width: Int) {
        self.color = color
        self.width = min(200, max(60, width))
    }

    public func render(_ snapshot: SystemSnapshot) -> String {
        let state = snapshot.activity
        let stateText = styled(state.rawValue, code: stateColor(state))
        let processCount = snapshot.processes.count
        let noun = processCount == 1 ? "process" : "processes"
        let cpuCapacity = Double(snapshot.logicalCPUCount) * 100
        let normalizedCPU = cpuCapacity > 0 ? snapshot.totalCPUPercent / cpuCapacity * 100 : 0
        let cpuValue = snapshot.processes.contains { $0.cpuPercent == nil }
            ? "warming up"
            : String(format: "%.1f%%  ≈ %.1f cores", snapshot.totalCPUPercent, snapshot.totalCPUPercent / 100)
        let gpuValue = snapshot.gpuPercent.map { String(format: "%.1f%% system-wide", $0) }
            ?? "unavailable"

        var lines = [
            styled("LLAMATOP", code: "1;36") + "  \(snapshot.machineName)",
            "\(stateText)  \(processCount) llama.cpp \(noun)",
            "",
            metricLine(label: "Llama CPU", percent: normalizedCPU, value: cpuValue),
            metricLine(label: "Apple GPU", percent: snapshot.gpuPercent, value: gpuValue),
            "Llama RAM  \(bytes(snapshot.totalResidentBytes)) / \(bytes(snapshot.physicalMemoryBytes)) physical",
            "",
        ]

        if snapshot.processes.isEmpty {
            lines.append("No llama.cpp process found. For renamed wrappers, try --match TEXT.")
        } else {
            lines.append(processHeader)
            lines.append(contentsOf: snapshot.processes.map(processLine))
        }

        lines.append("")
        lines.append("GPU is system-wide and may include other apps; CPU and RAM are llama.cpp-only.")
        return lines.joined(separator: "\n")
    }

    private var processHeader: String {
        "   PID    CPU       RAM       TIME  COMMAND"
    }

    private func processLine(_ process: MonitoredProcess) -> String {
        let cpu = process.cpuPercent.map { String(format: "%6.1f%%", $0) } ?? " warmup"
        let prefix = String(
            format: "%6d %@ %9@ %10@  ",
            process.pid,
            cpu,
            bytes(process.residentBytes),
            process.elapsed
        )
        return prefix + truncated(process.command, to: max(10, width - prefix.count))
    }

    private func metricLine(label: String, percent: Double?, value: String) -> String {
        let labelField = label.padding(toLength: 10, withPad: " ", startingAt: 0)
        return "\(labelField) \(bar(percent))  \(value)"
    }

    private func bar(_ percent: Double?) -> String {
        let length = max(10, min(28, width - 54))
        guard let percent else { return "[\(String(repeating: "·", count: length))]" }
        let filled = Int((min(100, max(0, percent)) / 100 * Double(length)).rounded())
        return "[\(styled(String(repeating: "█", count: filled), code: "32"))\(String(repeating: "░", count: length - filled))]"
    }

    private func stateColor(_ state: ActivityState) -> String {
        switch state {
        case .busy: "1;32"
        case .idle: "1;33"
        case .notFound: "1;31"
        }
    }

    private func styled(_ value: String, code: String) -> String {
        color ? "\u{001B}[\(code)m\(value)\u{001B}[0m" : value
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

    private func truncated(_ value: String, to length: Int) -> String {
        guard value.count > length else { return value }
        guard length > 1 else { return "…" }
        return String(value.prefix(length - 1)) + "…"
    }
}
