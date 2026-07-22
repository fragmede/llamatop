public enum ActivityClassifier {
    private static let cpuNoiseFloor = 1.0

    public static func classify(processes: [MonitoredProcess]) -> ActivityState {
        guard !processes.isEmpty else { return .notFound }
        let cpuPercent = processes.compactMap(\.cpuPercent).reduce(0, +)
        if cpuPercent >= cpuNoiseFloor { return .busy }
        if processes.contains(where: { $0.cpuPercent == nil }) { return .warmingUp }
        return .idle
    }

    static func isKnownIdle(_ process: MonitoredProcess) -> Bool {
        guard let cpuPercent = process.cpuPercent else { return false }
        return cpuPercent < cpuNoiseFloor
    }
}
