import CoreFoundation
import Foundation
import IOKit

protocol GPUProbing {
    func capture() -> GPUStatistics?
}

struct AppleGPUProbe: GPUProbing {
    func capture() -> GPUStatistics? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AGXAccelerator"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var metadataFallback: GPUStatistics?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let performance = property(named: "PerformanceStatistics", from: service)
            let coreCount = property(named: "gpu-core-count", from: service)
            let model = property(named: "model", from: service)
            IOObjectRelease(service)

            if let statistics = GPUStatisticsParser.parse(
                performanceStatistics: performance,
                coreCount: coreCount,
                model: model
            ) {
                if statistics.hasActivityMetrics { return statistics }
                metadataFallback = metadataFallback ?? statistics
            }
            service = IOIteratorNext(iterator)
        }
        return metadataFallback
    }

    private func property(named name: String, from service: io_registry_entry_t) -> Any? {
        IORegistryEntryCreateCFProperty(
            service,
            name as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue()
    }
}

public enum GPUStatisticsParser {
    public static func parse(
        performanceStatistics: Any?,
        coreCount: Any?,
        model: Any?
    ) -> GPUStatistics? {
        let performance = performanceStatistics as? [String: Any]
        let statistics = GPUStatistics(
            model: model as? String,
            coreCount: positiveInt(coreCount),
            devicePercent: percentage(performance?["Device Utilization %"]),
            rendererPercent: percentage(performance?["Renderer Utilization %"]),
            tilerPercent: percentage(performance?["Tiler Utilization %"]),
            allocatedSystemMemoryBytes: nonnegativeUInt64(performance?["Alloc system memory"]),
            inUseSystemMemoryBytes: nonnegativeUInt64(performance?["In use system memory"])
        )
        return statistics.hasAnyMetric ? statistics : nil
    }

    private static func percentage(_ value: Any?) -> Double? {
        guard let value = double(value) else { return nil }
        return min(100, max(0, value))
    }

    private static func positiveInt(_ value: Any?) -> Int? {
        if let number = value as? NSNumber, number.int64Value > 0 {
            return Int(exactly: number.int64Value)
        }
        if let string = value as? String, let parsed = Int(string), parsed > 0 {
            return parsed
        }
        return nil
    }

    private static func nonnegativeUInt64(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber, number.int64Value >= 0 {
            return UInt64(number.int64Value)
        }
        if let string = value as? String {
            return UInt64(string)
        }
        return nil
    }

    private static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}

private extension GPUStatistics {
    var hasActivityMetrics: Bool {
        devicePercent != nil || rendererPercent != nil || tilerPercent != nil
    }

    var hasAnyMetric: Bool {
        model != nil
            || coreCount != nil
            || hasActivityMetrics
            || allocatedSystemMemoryBytes != nil
            || inUseSystemMemoryBytes != nil
    }
}
