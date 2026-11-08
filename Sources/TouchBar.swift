/*
 TouchBar.swift
 EinsteinCat

 Gatito en la tira de control de la Touch Bar (usa APIs PRIVADAS de macOS).
 Basado en cómo lo hace MTMR (github.com/Toxblh/MTMR, TouchBarController.swift).
*/

import Cocoa

/// Firma de la función C privada de DFRFoundation:
///   void DFRElementSetControlStripPresenceForIdentifier(NSString *identifier, BOOL present);
/// `@convention(c)` le dice a Swift que es una función C. NSString y CFString son
/// intercambiables ("toll-free bridged"); BOOL de Objective-C es `ObjCBool` en Swift.
private typealias SetControlStripPresence = @convention(c) (CFString, ObjCBool) -> Void

final class ControlStripCat: NSObject {
    static let identifier = NSTouchBarItem.Identifier("com.jeloercc.einsteincat.controlStrip")

    private let item = NSCustomTouchBarItem(identifier: ControlStripCat.identifier)
    private let setPresence: SetControlStripPresence?
    private var button: NSButton!

    /// Máximo de cambios de cuadro por segundo en la Touch Bar (para no gastar CPU de más).
    private let minFrameInterval: TimeInterval = 1.0 / 30.0
    private var lastFrameTime: TimeInterval = 0

    init(image: NSImage) {
        setPresence = ControlStripCat.loadSetPresence()
        super.init()
        button = NSButton(image: image, target: self, action: #selector(tapped(_:)))
        item.view = button
    }

    /// Cambia el cuadro del gatito. Se salta cuadros si llegan más de 30 por segundo.
    func setFrame(_ image: NSImage) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFrameTime >= minFrameInterval else { return }
        lastFrameTime = now
        button.image = image
    }

    /// Pone el gatito en la tira de control (mismo orden que MTMR).
    func show() {
        guard let setPresence else {
            NSLog("EinsteinCat: no se pudo cargar DFRFoundation; el gatito no aparecerá en la Touch Bar")
            return
        }
        NSLog("EinsteinCat: responde a addSystemTrayItem: %d",
              NSTouchBarItem.responds(to: NSSelectorFromString("addSystemTrayItem:")) ? 1 : 0)
        NSTouchBarItem.addSystemTrayItem(item)
        NSLog("EinsteinCat: addSystemTrayItem llamado")
        setPresence(ControlStripCat.identifier.rawValue as CFString, true)
        NSLog("EinsteinCat: presencia activada")
    }

    /// Quita el gatito (al cerrar la app).
    func hide() {
        setPresence?(ControlStripCat.identifier.rawValue as CFString, false)
        NSTouchBarItem.removeSystemTrayItem(item)
    }

    @objc private func tapped(_ sender: NSButton) {
        // Fase 2: solo confirmar que el toque llega. Correr por la Touch Bar es la Fase 3.
        NSLog("EinsteinCat: tocaron el gatito")
    }

    /// DFRFoundation no existe como archivo en disco (vive en la caché compartida de dyld),
    /// así que no se puede enlazar al compilar: se carga en tiempo de ejecución.
    private static func loadSetPresence() -> SetControlStripPresence? {
        let path = "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            NSLog("EinsteinCat: dlopen falló: %@", String(cString: dlerror()))
            return nil
        }
        guard let symbol = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") else {
            NSLog("EinsteinCat: dlsym falló: %@", String(cString: dlerror()))
            return nil
        }
        NSLog("EinsteinCat: DFRFoundation cargado")
        // Convertir el puntero "crudo" a una función C con la firma de arriba.
        return unsafeBitCast(symbol, to: SetControlStripPresence.self)
    }
}
