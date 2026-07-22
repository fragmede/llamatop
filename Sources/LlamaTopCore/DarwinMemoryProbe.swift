import Darwin
import Foundation

protocol MemoryProbing {
    func capture() -> MemoryStatistics?
}

struct MemoryPageCounts: Equatable, Sendable {
    let active: UInt64
    let inactive: UInt64
    let wired: UInt64
    let compressed: UInt64
    let free: UInt64
}

struct MemoryHardwareInfo: Equatable, Sendable {
    let memoryType: String?
    let manufacturer: String?
}

enum MemoryStatisticsBuilder {
    static func build(
        counts: MemoryPageCounts,
        pageSizeBytes: UInt64,
        cacheLineBytes: UInt64?,
        swapTotalBytes: UInt64?,
        swapUsedBytes: UInt64?,
        hardware: MemoryHardwareInfo?
    ) -> MemoryStatistics {
        MemoryStatistics(
            activeBytes: bytes(pages: counts.active, pageSize: pageSizeBytes),
            inactiveBytes: bytes(pages: counts.inactive, pageSize: pageSizeBytes),
            wiredBytes: bytes(pages: counts.wired, pageSize: pageSizeBytes),
            compressedBytes: bytes(pages: counts.compressed, pageSize: pageSizeBytes),
            freeBytes: bytes(pages: counts.free, pageSize: pageSizeBytes),
            pageSizeBytes: pageSizeBytes,
            cacheLineBytes: cacheLineBytes,
            swapTotalBytes: swapTotalBytes,
            swapUsedBytes: swapUsedBytes,
            memoryType: hardware?.memoryType,
            manufacturer: hardware?.manufacturer
        )
    }

    private static func bytes(pages: UInt64, pageSize: UInt64) -> UInt64 {
        let result = pages.multipliedReportingOverflow(by: pageSize)
        return result.overflow ? UInt64.max : result.partialValue
    }

}

enum MemoryHardwareParser {
    static func parse(_ data: Data) -> MemoryHardwareInfo? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["SPMemoryDataType"] as? [[String: Any]] else {
            return nil
        }

        let memoryType = firstValue(named: "dimm_type", in: entries)
        let manufacturer = firstValue(named: "dimm_manufacturer", in: entries)
        guard memoryType != nil || manufacturer != nil else { return nil }
        return MemoryHardwareInfo(memoryType: memoryType, manufacturer: manufacturer)
    }

    private static func firstValue(
        named key: String,
        in entries: [[String: Any]]
    ) -> String? {
        entries.lazy.compactMap { entry in
            guard let value = entry[key] as? String, !value.isEmpty else { return nil }
            return value
        }.first
    }
}

struct DarwinMemoryProbe: MemoryProbing {
    private let hardware: MemoryHardwareInfo?

    init(hardware: MemoryHardwareInfo? = SystemMemoryHardwareProbe.capture()) {
        self.hardware = hardware
    }

    func capture() -> MemoryStatistics? {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout.size(ofValue: statistics) / MemoryLayout<integer_t>.stride
        )
        let status = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }

        let swap = Self.readSwapUsage()
        return MemoryStatisticsBuilder.build(
            counts: MemoryPageCounts(
                active: UInt64(statistics.active_count),
                inactive: UInt64(statistics.inactive_count),
                wired: UInt64(statistics.wire_count),
                compressed: UInt64(statistics.compressor_page_count),
                free: UInt64(statistics.free_count)
            ),
            pageSizeBytes: UInt64(pageSize),
            cacheLineBytes: Self.readUInt64Sysctl("hw.cachelinesize"),
            swapTotalBytes: swap?.total,
            swapUsedBytes: swap?.used,
            hardware: hardware
        )
    }

    private static func readSwapUsage() -> (total: UInt64, used: UInt64)? {
        var usage = xsw_usage()
        var size = MemoryLayout.size(ofValue: usage)
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return nil }
        return (usage.xsu_total, usage.xsu_used)
    }

    private static func readUInt64Sysctl(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout.size(ofValue: value)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}

private enum SystemMemoryHardwareProbe {
    static func capture() -> MemoryHardwareInfo? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPMemoryDataType", "-json"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == EXIT_SUCCESS else { return nil }
        return MemoryHardwareParser.parse(data)
    }
}
