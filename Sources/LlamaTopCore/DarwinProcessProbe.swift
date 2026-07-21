import Darwin
import Foundation

struct ProcessIdentity: Hashable, Sendable {
    let pid: pid_t
    let startSeconds: UInt64
    let startMicroseconds: UInt64
}

struct RawProcessSample: Sendable {
    let identity: ProcessIdentity
    let parentPID: pid_t
    let totalCPUTimeTicks: UInt64
    let residentBytes: UInt64
    let elapsedSeconds: TimeInterval
    let executable: String
    let command: String
}

protocol ProcessProbing {
    func capture(at date: Date) -> [RawProcessSample]
}

struct DarwinProcessProbe: ProcessProbing {
    func capture(at date: Date) -> [RawProcessSample] {
        allProcessIDs().compactMap { sample(pid: $0, at: date) }
    }

    private func allProcessIDs() -> [pid_t] {
        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(estimatedCount) + 32)
        let count = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return [] }
        return Array(pids.prefix(Int(count))).filter { $0 > 0 }
    }

    private func sample(pid: pid_t, at date: Date) -> RawProcessSample? {
        var task = proc_taskinfo()
        let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, taskSize) == taskSize else {
            return nil
        }

        var bsd = proc_bsdinfo()
        let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, bsdSize) == bsdSize else {
            return nil
        }

        guard let executable = executablePath(pid: pid) else { return nil }
        var arguments = commandLine(pid: pid)
        if !arguments.isEmpty {
            arguments[0] = URL(fileURLWithPath: executable).lastPathComponent
        }
        let command = arguments.isEmpty ? executable : CommandSanitizer.display(arguments: arguments)
        let start = TimeInterval(bsd.pbi_start_tvsec)
            + TimeInterval(bsd.pbi_start_tvusec) / 1_000_000

        return RawProcessSample(
            identity: .init(
                pid: pid,
                startSeconds: bsd.pbi_start_tvsec,
                startMicroseconds: bsd.pbi_start_tvusec
            ),
            parentPID: pid_t(bsd.pbi_ppid),
            totalCPUTimeTicks: task.pti_total_user &+ task.pti_total_system,
            residentBytes: task.pti_resident_size,
            elapsedSeconds: max(0, date.timeIntervalSince1970 - start),
            executable: executable,
            command: command
        )
    }

    private func executablePath(pid: pid_t) -> String? {
        var buffer = [UInt8](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)), as: UTF8.self)
    }

    private func commandLine(pid: pid_t) -> [String] {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else {
            return []
        }

        var bytes = [UInt8](repeating: 0, count: size)
        let result = bytes.withUnsafeMutableBytes { buffer in
            sysctl(&mib, UInt32(mib.count), buffer.baseAddress, &size, nil, 0)
        }
        guard result == 0, size >= MemoryLayout<Int32>.size else { return [] }

        let argumentCount = bytes.withUnsafeBytes {
            Int($0.loadUnaligned(as: Int32.self))
        }
        guard argumentCount > 0 else { return [] }

        var cursor = MemoryLayout<Int32>.size
        skipNonZero(in: bytes, cursor: &cursor, limit: size)
        skipZero(in: bytes, cursor: &cursor, limit: size)

        var arguments: [String] = []
        while arguments.count < argumentCount, cursor < size {
            let start = cursor
            skipNonZero(in: bytes, cursor: &cursor, limit: size)
            if cursor > start {
                arguments.append(String(decoding: bytes[start..<cursor], as: UTF8.self))
            }
            skipZero(in: bytes, cursor: &cursor, limit: size)
        }
        return arguments
    }

    private func skipNonZero(in bytes: [UInt8], cursor: inout Int, limit: Int) {
        while cursor < limit, bytes[cursor] != 0 { cursor += 1 }
    }

    private func skipZero(in bytes: [UInt8], cursor: inout Int, limit: Int) {
        while cursor < limit, bytes[cursor] == 0 { cursor += 1 }
    }
}
