import Darwin

struct CPUCoreTicks: Equatable, Sendable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32
}

protocol CPUCoreProbing {
    func capture() -> [CPUCoreTicks]?
}

struct DarwinCPUCoreProbe: CPUCoreProbing {
    func capture() -> [CPUCoreTicks]? {
        var processorCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let status = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &info,
            &infoCount
        )
        guard status == KERN_SUCCESS, let info else { return nil }
        defer {
            let byteCount = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            _ = vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                byteCount
            )
        }

        let stateCount = Int(CPU_STATE_MAX)
        guard stateCount > 0, Int(infoCount) >= Int(processorCount) * stateCount else {
            return nil
        }

        return (0..<Int(processorCount)).map { processor in
            let base = processor * stateCount
            return CPUCoreTicks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            )
        }
    }
}

enum CPUCoreUsageCalculator {
    static func percentages(
        previous: [CPUCoreTicks]?,
        current: [CPUCoreTicks]
    ) -> [Double?] {
        guard let previous, previous.count == current.count else {
            return Array(repeating: nil, count: current.count)
        }

        return zip(previous, current).map { old, new in
            let user = UInt64(new.user &- old.user)
            let system = UInt64(new.system &- old.system)
            let idle = UInt64(new.idle &- old.idle)
            let nice = UInt64(new.nice &- old.nice)
            let total = user + system + idle + nice
            guard total > 0 else { return 0 }
            return Double(user + system + nice) / Double(total) * 100
        }
    }
}
