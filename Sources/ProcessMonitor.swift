/*
 ProcessMonitor.swift
 EinsteinCat

 Monitor de procesos del kernel mediante libproc.
 Devuelve la lista completa de tareas activas del sistema ordenadas por CPU y RAM.
*/

import Darwin
import Foundation

struct ProcessTask {
    let pid: pid_t
    let name: String
    let cpuPercent: Double
    let memoryBytes: UInt64

    var memoryFormatted: String {
        let mb = Double(memoryBytes) / (1024.0 * 1024.0)
        if mb >= 1024.0 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }

    var cpuFormatted: String {
        return String(format: "%4.1f%%", cpuPercent)
    }
}

final class ProcessMonitor {
    private var previousTimes: [pid_t: (cpuNs: UInt64, time: TimeInterval)] = [:]

    func allProcesses() -> [ProcessTask] {
        let now = ProcessInfo.processInfo.systemUptime

        let bytesNeeded = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bytesNeeded > 0 else { return [] }

        let count = Int(bytesNeeded) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: count)
        let actualBytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bytesNeeded)
        guard actualBytes > 0 else { return [] }

        let actualCount = Int(actualBytes) / MemoryLayout<pid_t>.size
        var tasks: [ProcessTask] = []
        var activePids = Set<pid_t>()

        for i in 0 ..< actualCount {
            let pid = pids[i]
            guard pid > 0 else { continue }
            activePids.insert(pid)

            var info = proc_taskinfo()
            let infoSize = Int32(MemoryLayout<proc_taskinfo>.size)
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, infoSize)
            guard result == infoSize else { continue }

            var nameBuffer = [CChar](repeating: 0, count: 256)
            let nameLen = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name: String
            if nameLen > 0 {
                name = String(cString: nameBuffer)
            } else {
                name = "PID \(pid)"
            }

            guard !name.isEmpty else { continue }

            let totalCpuNs = info.pti_total_user + info.pti_total_system
            var cpuPct: Double = 0.0

            if let prev = previousTimes[pid] {
                let deltaNs = (totalCpuNs >= prev.cpuNs) ? (totalCpuNs - prev.cpuNs) : 0
                let deltaSec = now - prev.time
                if deltaSec > 0.05 {
                    cpuPct = (Double(deltaNs) / (deltaSec * 1_000_000_000.0)) * 100.0
                }
            }
            previousTimes[pid] = (totalCpuNs, now)

            let memBytes = UInt64(info.pti_resident_size)
            tasks.append(ProcessTask(pid: pid, name: name, cpuPercent: cpuPct, memoryBytes: memBytes))
        }

        // Limpiar procesos que ya cerraron
        previousTimes = previousTimes.filter { activePids.contains($0.key) }

        // Ordenar: primero por uso de CPU, luego por memoria
        tasks.sort {
            if abs($0.cpuPercent - $1.cpuPercent) > 0.2 {
                return $0.cpuPercent > $1.cpuPercent
            }
            return $0.memoryBytes > $1.memoryBytes
        }

        return tasks
    }

    func topProcesses(limit: Int = 5) -> [ProcessTask] {
        let tasks = allProcesses()
        if limit > 0 {
            return Array(tasks.prefix(limit))
        }
        return tasks
    }
}
