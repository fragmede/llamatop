public enum CPUUsageCalculator {
    public static func percent(
        previousCPUTimeTicks: UInt64?,
        currentCPUTimeTicks: UInt64,
        elapsedTicks: UInt64
    ) -> Double? {
        guard
            let previousCPUTimeTicks,
            currentCPUTimeTicks >= previousCPUTimeTicks,
            elapsedTicks > 0
        else {
            return nil
        }

        let used = currentCPUTimeTicks - previousCPUTimeTicks
        return Double(used) / Double(elapsedTicks) * 100
    }
}
