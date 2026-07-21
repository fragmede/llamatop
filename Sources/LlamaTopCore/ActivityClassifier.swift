public enum ActivityClassifier {
    private static let cpuNoiseFloor = 1.0

    public static func classify(
        processes: [MonitoredProcess],
        gpuPercent _: Double?
    ) -> ActivityState {
        guard !processes.isEmpty else { return .notFound }
        let cpuPercent = processes.compactMap(\.cpuPercent).reduce(0, +)
        return cpuPercent >= cpuNoiseFloor ? .busy : .idle
    }
}
