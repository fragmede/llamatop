import Darwin
import Foundation

protocol MonitorEnvironment {
    var machineName: String { get }
    var logicalCPUCount: Int { get }
    var physicalMemoryBytes: UInt64 { get }
    func currentDate() -> Date
    func currentUptimeTicks() -> UInt64
}

struct SystemMonitorEnvironment: MonitorEnvironment {
    let machineName: String
    let logicalCPUCount: Int
    let physicalMemoryBytes: UInt64

    init() {
        machineName = Self.readMachineName()
        logicalCPUCount = max(1, ProcessInfo.processInfo.processorCount)
        physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
    }

    func currentDate() -> Date {
        Date()
    }

    func currentUptimeTicks() -> UInt64 {
        mach_absolute_time()
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
