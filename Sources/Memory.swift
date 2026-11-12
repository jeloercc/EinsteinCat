/*
 Memory.swift
 EinsteinCat

 Lector de estadísticas de memoria RAM mediante la API de Mach kernel (HOST_VM_INFO64).
 Fase C: Desglose de memoria física, activa, wired, comprimida y libre.
*/

import Darwin
import Foundation

struct RAMInfo {
    let usedBytes: UInt64
    let totalBytes: UInt64
    let freeBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64

    var usedGB: Double { Double(usedBytes) / 1_073_741_824.0 }
    var totalGB: Double { Double(totalBytes) / 1_073_741_824.0 }
    var freeGB: Double { Double(freeBytes) / 1_073_741_824.0 }
    var appGB: Double { Double(appBytes) / 1_073_741_824.0 }
    var wiredGB: Double { Double(wiredBytes) / 1_073_741_824.0 }
    var compressedGB: Double { Double(compressedBytes) / 1_073_741_824.0 }
    var swapUsedGB: Double { Double(swapUsedBytes) / 1_073_741_824.0 }
    var swapTotalGB: Double { Double(swapTotalBytes) / 1_073_741_824.0 }

    var percentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(100.0, (Double(usedBytes) / Double(totalBytes)) * 100.0)
    }

    static let `default` = RAMInfo(
        usedBytes: 0,
        totalBytes: ProcessInfo.processInfo.physicalMemory,
        freeBytes: ProcessInfo.processInfo.physicalMemory,
        appBytes: 0,
        wiredBytes: 0,
        compressedBytes: 0,
        swapUsedBytes: 0,
        swapTotalBytes: 0
    )
}

final class RAM {
    private let hostPort = mach_host_self()
    private let pageSize: UInt64

    init() {
        var size: vm_size_t = 0
        _ = _host_page_size(mach_host_self(), &size)
        self.pageSize = (size > 0) ? UInt64(size) : 4096
    }

    func currentUsage() -> RAMInfo {
        let total = ProcessInfo.processInfo.physicalMemory
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics64()

        let kerr = withUnsafeMutablePointer(to: &vmStat) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard kerr == KERN_SUCCESS else {
            return RAMInfo.default
        }

        // Conversión de páginas a bytes
        let active = UInt64(vmStat.active_count) * pageSize
        let wired = UInt64(vmStat.wire_count) * pageSize
        let compressed = UInt64(vmStat.compressor_page_count) * pageSize
        let inactive = UInt64(vmStat.inactive_count) * pageSize
        let free = UInt64(vmStat.free_count) * pageSize

        // Memoria utilizada según el estándar de macOS (Monitor de Actividad)
        let used = active + wired + compressed
        let freeCalculated = (total > used) ? (total - used) : (inactive + free)

        let swap = swapUsage()
        return RAMInfo(
            usedBytes: used,
            totalBytes: total,
            freeBytes: freeCalculated,
            appBytes: active,
            wiredBytes: wired,
            compressedBytes: compressed,
            swapUsedBytes: swap.used,
            swapTotalBytes: swap.total
        )
    }

    private func swapUsage() -> (used: UInt64, total: UInt64) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        process.arguments = ["vm.swapusage"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (0, 0)
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let values = output.split(whereSeparator: { $0 == " " || $0 == "\n" })

        func megabytes(after key: String) -> UInt64 {
            guard let index = values.firstIndex(where: { $0 == key }), index + 2 < values.endIndex else {
                return 0
            }
            let valueIndex = values[index + 1] == "=" ? index + 2 : index + 1
            return UInt64((Double(values[valueIndex].dropLast()) ?? 0) * 1_048_576)
        }

        return (megabytes(after: "used"), megabytes(after: "total"))
    }
}
