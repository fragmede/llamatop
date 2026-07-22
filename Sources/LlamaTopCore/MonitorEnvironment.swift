import Darwin
import Foundation

protocol MonitorEnvironment {
    var machineName: String { get }
    var logicalCPUCount: Int { get }
    var performanceCoreCount: Int? { get }
    var efficiencyCoreCount: Int? { get }
    var physicalMemoryBytes: UInt64 { get }
    func currentDate() -> Date
    func currentUptimeTicks() -> UInt64
}

struct SystemMonitorEnvironment: MonitorEnvironment {
    let machineName: String
    let logicalCPUCount: Int
    let performanceCoreCount: Int?
    let efficiencyCoreCount: Int?
    let physicalMemoryBytes: UInt64

    init() {
        machineName = Self.readMachineName()
        logicalCPUCount = max(1, ProcessInfo.processInfo.processorCount)
        performanceCoreCount = Self.readInt("hw.perflevel0.logicalcpu")
        if Self.readString("hw.perflevel1.name")?.lowercased().contains("efficiency") == true {
            efficiencyCoreCount = Self.readInt("hw.perflevel1.logicalcpu")
        } else {
            efficiencyCoreCount = nil
        }
        physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
    }

    func currentDate() -> Date {
        Date()
    }

    func currentUptimeTicks() -> UInt64 {
        mach_absolute_time()
    }

    private static func readMachineName() -> String {
        readString("machdep.cpu.brand_string") ?? "Apple Silicon Mac"
    }

    private static func readInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout.size(ofValue: value)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0,
              size == MemoryLayout.size(ofValue: value),
              value >= 0 else {
            return nil
        }
        return Int(value)
    }

    private static func readString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
        let utf8 = bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: utf8, as: UTF8.self)
    }
}
