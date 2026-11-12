/*
 CPU.swift
 Menubar RunCat

 Created by Takuto Nakamura on 2019/08/06.
 Copyright © 2019 Takuto Nakamura. All rights reserved.

 Modificado para EinsteinCat (Fase B):
 - CPUInfo como struct con desglose de usuario y sistema.
 - Historial circular de las últimas 30 lecturas para dibujar la gráfica.
*/

import Darwin

struct CPUInfo {
    let value: Double
    let user: Double
    let system: Double
    let description: String
    let coreUsage: [Double]
    let loadAverage: [Double]

    static let `default` = CPUInfo(
        value: 0.0,
        user: 0.0,
        system: 0.0,
        description: " 0.0% ",
        coreUsage: [],
        loadAverage: [0, 0, 0]
    )

    init(
        value: Double,
        user: Double = 0.0,
        system: Double = 0.0,
        description: String,
        coreUsage: [Double] = [],
        loadAverage: [Double] = [0, 0, 0]
    ) {
        self.value = value
        self.user = user
        self.system = system
        self.description = description
        self.coreUsage = coreUsage
        self.loadAverage = loadAverage
    }
}

final class CPU {
    static let `default` = CPUInfo.default

    private let loadInfoCount: mach_msg_type_number_t!
    private var loadPrevious = host_cpu_load_info()
    private var corePrevious: [UInt32] = []
    
    let maxHistory: Int = 30
    private(set) var history: [Double]

    init() {
        loadInfoCount = UInt32(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        history = Array(repeating: 0.0, count: maxHistory)
    }
    
    private func hostCPULoadInfo() -> host_cpu_load_info {
        var size: mach_msg_type_number_t = loadInfoCount
        let hostInfo = host_cpu_load_info_t.allocate(capacity: 1)
        let _ = hostInfo.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { (pointer) -> kern_return_t in
            return host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, pointer, &size)
        }
        let data = hostInfo.move()
        hostInfo.deallocate()
        return data
    }
    
    func currentUsage() -> CPUInfo {
        let load = hostCPULoadInfo()
        let userDiff = Double(load.cpu_ticks.0 - loadPrevious.cpu_ticks.0)
        let sysDiff  = Double(load.cpu_ticks.1 - loadPrevious.cpu_ticks.1)
        let idleDiff = Double(load.cpu_ticks.2 - loadPrevious.cpu_ticks.2)
        let niceDiff = Double(load.cpu_ticks.3 - loadPrevious.cpu_ticks.3)
        loadPrevious = load
        
        let totalTicks = sysDiff + userDiff + idleDiff + niceDiff
        guard totalTicks > 0 else {
            return CPUInfo.default
        }
        let sys  = 100.0 * sysDiff / totalTicks
        let user = 100.0 * userDiff / totalTicks

        let value = min(99.9, (10.0 * (sys + user)).rounded() / 10.0)
        let userVal = (10.0 * user).rounded() / 10.0
        let sysVal  = (10.0 * sys).rounded() / 10.0
        let description = String(format: "%4.1f%%", value)

        if history.count >= maxHistory {
            history.removeFirst()
        }
        history.append(value)
        
        let coreUsage = currentCoreUsage()
        var loads = [Double](repeating: 0, count: 3)
        _ = getloadavg(&loads, 3)

        return CPUInfo(
            value: value,
            user: userVal,
            system: sysVal,
            description: description,
            coreUsage: coreUsage,
            loadAverage: loads
        )
    }

    private func currentCoreUsage() -> [Double] {
        var processorCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &info,
            &infoCount
        )
        guard result == KERN_SUCCESS, let info else { return [] }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        let values = Array(UnsafeBufferPointer(start: info, count: Int(infoCount)))
        var usage: [Double] = []
        for core in 0 ..< Int(processorCount) {
            let offset = core * Int(CPU_STATE_MAX)
            guard offset + Int(CPU_STATE_MAX) <= values.count else { continue }
            let user = UInt64(values[offset + Int(CPU_STATE_USER)])
            let system = UInt64(values[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(values[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(values[offset + Int(CPU_STATE_NICE)])
            let total = user + system + idle + nice
            let previousTotal = corePrevious.dropFirst(offset).prefix(Int(CPU_STATE_MAX)).reduce(UInt64(0)) { $0 + UInt64($1) }
            let previousBusy = corePrevious.count >= offset + Int(CPU_STATE_MAX)
                ? UInt64(corePrevious[offset + Int(CPU_STATE_USER)] + corePrevious[offset + Int(CPU_STATE_SYSTEM)])
                : 0
            let busy = user + system
            usage.append(previousTotal < total ? min(100, Double(busy - previousBusy) / Double(total - previousTotal) * 100) : 0)
        }
        corePrevious = values.map(UInt32.init)
        return usage
    }
}
