/*
 SystemMetrics.swift
 EinsteinCat

 Lectura de almacenamiento, batería y tráfico de red para el panel de hardware.
*/

import Foundation

struct DiskVolumeInfo {
    let name: String
    let usedGB: Double
    let freeGB: Double
    let totalGB: Double
    let isInternal: Bool
}

struct PowerInfo {
    let level: Double
    let state: String
    let timeRemaining: String
    let health: Double?
    let cycles: Int?
}

struct NetworkInfo {
    let downloadMBps: Double
    let uploadMBps: Double
}

struct DiskActivityInfo {
    let readMBps: Double
    let writeMBps: Double
}

struct SystemMetricsInfo {
    let volumes: [DiskVolumeInfo]
    let power: PowerInfo
    let network: NetworkInfo
    let diskActivity: DiskActivityInfo

    static let empty = SystemMetricsInfo(
        volumes: [],
        power: PowerInfo(level: 0, state: "Unknown", timeRemaining: "--", health: nil, cycles: nil),
        network: NetworkInfo(downloadMBps: 0, uploadMBps: 0),
        diskActivity: DiskActivityInfo(readMBps: 0, writeMBps: 0)
    )
}

final class SystemMetrics {
    private var previousNetworkBytes: (received: UInt64, sent: UInt64)?
    private var previousNetworkTime: TimeInterval?

    func current() -> SystemMetricsInfo {
        SystemMetricsInfo(
            volumes: mountedVolumes(),
            power: powerStatus(),
            network: networkStatus(),
            diskActivity: diskActivity()
        )
    }

    private func mountedVolumes() -> [DiskVolumeInfo] {
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeIsInternalKey
            ],
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard
                let values = try? url.resourceValues(forKeys: [
                    .volumeNameKey,
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityKey,
                    .volumeIsInternalKey
                ]),
                let total = values.volumeTotalCapacity,
                let free = values.volumeAvailableCapacity,
                total > 0
            else {
                return nil
            }

            let unit = 1_073_741_824.0
            return DiskVolumeInfo(
                name: values.volumeName ?? url.lastPathComponent,
                usedGB: Double(total - free) / unit,
                freeGB: Double(free) / unit,
                totalGB: Double(total) / unit,
                isInternal: values.volumeIsInternal ?? false
            )
        }
        .sorted { lhs, rhs in
            if lhs.isInternal != rhs.isInternal {
                return lhs.isInternal
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func powerStatus() -> PowerInfo {
        let output = command("/usr/bin/pmset", arguments: ["-g", "batt"])
        let batteryLine = output.split(separator: "\n").first { $0.contains("%") }
        guard let batteryLine else {
            return PowerInfo(level: 0, state: "No battery", timeRemaining: "--", health: nil, cycles: nil)
        }

        let text = String(batteryLine)
        let percentText = text.split(separator: "%").first?.split(whereSeparator: { !$0.isNumber }).last
        let level = percentText.flatMap { Double($0) } ?? 0
        let state = text.contains("discharging") ? "Discharging" :
            (text.contains("charging") ? "Charging" : "Charged")
        let time = text.split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { $0.contains("remaining") }) ?? "--"
        let cleanTime = time.components(separatedBy: " present:").first ?? time
        return PowerInfo(level: level, state: state, timeRemaining: cleanTime, health: nil, cycles: nil)
    }

    private func networkStatus() -> NetworkInfo {
        let output = command("/usr/sbin/netstat", arguments: ["-ib"])
        var received: UInt64 = 0
        var sent: UInt64 = 0

        for line in output.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count >= 10, fields[0] != "Name", fields[0] != "lo0" else { continue }
            guard let inputBytes = UInt64(fields[6]), let outputBytes = UInt64(fields[9]) else { continue }
            received += inputBytes
            sent += outputBytes
        }

        let now = ProcessInfo.processInfo.systemUptime
        defer {
            previousNetworkBytes = (received, sent)
            previousNetworkTime = now
        }

        guard
            let previousNetworkBytes,
            let previousNetworkTime,
            now > previousNetworkTime
        else {
            return NetworkInfo(downloadMBps: 0, uploadMBps: 0)
        }

        let seconds = now - previousNetworkTime
        let megabyte = 1_048_576.0
        return NetworkInfo(
            downloadMBps: Double(received - previousNetworkBytes.received) / seconds / megabyte,
            uploadMBps: Double(sent - previousNetworkBytes.sent) / seconds / megabyte
        )
    }

    private func diskActivity() -> DiskActivityInfo {
        let output = command("/usr/sbin/iostat", arguments: ["-d", "-c", "1"])
        guard let dataLine = output.split(separator: "\n").last else {
            return DiskActivityInfo(readMBps: 0, writeMBps: 0)
        }
        let values = dataLine.split(whereSeparator: { $0 == " " || $0 == "\t" }).compactMap { Double($0) }
        guard values.count >= 3 else {
            return DiskActivityInfo(readMBps: 0, writeMBps: 0)
        }
        let mbps = stride(from: 2, to: values.count, by: 3).reduce(0.0) { $0 + values[$1] }
        return DiskActivityInfo(readMBps: mbps, writeMBps: 0)
    }

    private func command(_ launchPath: String, arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        } catch {
            NSLog("EinsteinCat: could not execute %@: %@", launchPath, error.localizedDescription)
            return ""
        }
    }
}
