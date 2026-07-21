import CoreFoundation
import Foundation
import IOKit

protocol GPUProbing {
    func utilization() -> Double?
}

struct AppleGPUProbe: GPUProbing {
    func utilization() -> Double? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AGXAccelerator"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            let property = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue()
            IOObjectRelease(service)

            if let property, let utilization = GPUUtilizationParser.parse(property) {
                return utilization
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }
}

public enum GPUUtilizationParser {
    public static func parse(_ value: Any) -> Double? {
        if let dictionary = value as? [String: Any] {
            if let metric = number(dictionary["Device Utilization %"]) {
                return min(100, max(0, metric))
            }
            for nested in dictionary.values {
                if let metric = parse(nested) { return metric }
            }
        } else if let array = value as? [Any] {
            for nested in array {
                if let metric = parse(nested) { return metric }
            }
        }
        return nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
