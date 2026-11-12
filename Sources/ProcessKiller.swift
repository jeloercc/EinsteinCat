/*
 ProcessKiller.swift
 EinsteinCat

 Módulo para enviar señales POSIX de control y terminación de procesos (kill).
 Fase F: Soporte para SIGTERM (cierre ordenado), SIGKILL (forzar cierre),
 SIGSTOP (congelar/pausar) y SIGCONT (reanudar/descongelar).
 Detección de telemetría y apps de segundo plano.
*/

import Darwin
import Foundation

enum KillSignal {
    case terminate // SIGTERM (15)
    case forceQuit  // SIGKILL (9)
    case suspend    // SIGSTOP (17)
    case resume     // SIGCONT (19)

    var signalCode: Int32 {
        switch self {
        case .terminate: return SIGTERM
        case .forceQuit: return SIGKILL
        case .suspend:   return SIGSTOP
        case .resume:    return SIGCONT
        }
    }

    var displayName: String {
        switch self {
        case .terminate: return "Terminate (SIGTERM)"
        case .forceQuit: return "Force Quit (SIGKILL)"
        case .suspend:   return "Pause / Freeze (SIGSTOP)"
        case .resume:    return "Resume (SIGCONT)"
        }
    }
}

enum KillResult {
    case success
    case permissionDenied
    case processNotFound
    case failed(errno: Int32, message: String)
}

final class ProcessKiller {
    static let knownTelemetry: Set<String> = [
        "analyticsd", "spindump", "symptomsd", "suggestd", "parsecd",
        "cloudd", "bird", "biometrickitd", "sharingd", "coreduetd",
        "diagnosticd", "osanalyticshelper"
    ]

    static func isTelemetryOrBackground(name: String) -> Bool {
        return knownTelemetry.contains(name.lowercased())
    }

    static func killProcess(pid: pid_t, signal: KillSignal) -> KillResult {
        // Protección contra terminar procesos críticos del kernel o a sí mismo
        guard pid > 1 else {
            return .permissionDenied
        }
        if pid == getpid() {
            return .permissionDenied
        }

        let res = Darwin.kill(pid, signal.signalCode)
        if res == 0 {
            return .success
        } else {
            let err = errno
            switch err {
            case EPERM:
                return .permissionDenied
            case ESRCH:
                return .processNotFound
            default:
                let msg = String(cString: strerror(err))
                return .failed(errno: err, message: msg)
            }
        }
    }
}
