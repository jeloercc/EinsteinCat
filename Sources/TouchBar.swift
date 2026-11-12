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
private typealias SetCloseBoxVisibility = @convention(c) (ObjCBool) -> Void

final class ControlStripCat: NSObject {
    static let identifier = NSTouchBarItem.Identifier("com.jeloercc.einsteincat.controlStrip")
    private static let modalItemIdentifier = NSTouchBarItem.Identifier("com.jeloercc.einsteincat.modal.item")

    private let item = NSCustomTouchBarItem(identifier: ControlStripCat.identifier)
    private let setPresence: SetControlStripPresence?
    private let setCloseBoxVisibility: SetCloseBoxVisibility?
    private var button: NSButton!
    private let onTap: () -> Void
    private let modalTouchBar = NSTouchBar()
    private let modalItem = NSCustomTouchBarItem(identifier: ControlStripCat.modalItemIdentifier)
    private let modalRunnerView = TouchBarRunnerView()
    private var modalVisible = false
    private var modalTimer: Timer?
    private var currentImage: NSImage

    /// Máximo de cambios de cuadro por segundo en la Touch Bar (para no gastar CPU de más).
    private let minFrameInterval: TimeInterval = 1.0 / 30.0
    private var lastFrameTime: TimeInterval = 0

    init(image: NSImage, onTap: @escaping () -> Void) {
        setPresence = ControlStripCat.loadSetPresence()
        setCloseBoxVisibility = ControlStripCat.loadSetCloseBoxVisibility()
        self.onTap = onTap
        self.currentImage = image
        super.init()
        button = NSButton(image: image, target: self, action: #selector(tapped(_:)))
        button.isBordered = false
        button.sendAction(on: [.leftMouseDown])
        item.view = button
        setupModalTouchBar()
    }

    /// Cambia el cuadro del gatito. Se salta cuadros si llegan más de 30 por segundo.
    func setFrame(_ image: NSImage) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFrameTime >= minFrameInterval else { return }
        lastFrameTime = now
        button.image = image
        currentImage = image
        modalRunnerView.setImage(image)
    }

    func setMotionSpeed(forCPU usage: CPUInfo) {
        let speed = max(3.0, min(18.0, 3.0 + usage.value / 6.0))
        modalRunnerView.motionStep = speed
    }

    func presentModal() {
        modalVisible = true
        setCloseBoxVisibility?(false)
        modalRunnerView.setImage(currentImage)
        modalRunnerView.startPosition()
        NSLog("EinsteinCat: presenting full-width Touch Bar modal")
        NSTouchBar.presentSystemModalTouchBar(
            modalTouchBar,
            systemTrayItemIdentifier: ControlStripCat.identifier
        )
        setPresence?(ControlStripCat.identifier.rawValue as CFString, true)
        NSLog("EinsteinCat: full-width Touch Bar modal requested")
        modalTimer?.invalidate()
        modalTimer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self, self.modalVisible else { return }
            self.modalRunnerView.advance()
        }
        RunLoop.main.add(modalTimer!, forMode: .common)
    }

    func dismissModal() {
        modalTimer?.invalidate()
        modalTimer = nil
        NSTouchBar.dismissSystemModalTouchBar(modalTouchBar)
        modalVisible = false
    }

    /// Pone el gatito en la tira de control (mismo orden que MTMR).
    func show() {
        guard let setPresence else {
            NSLog("EinsteinCat: could not load DFRFoundation; the cat will not appear in the Touch Bar")
            return
        }
        setPresence(ControlStripCat.identifier.rawValue as CFString, false)
        NSLog("EinsteinCat: addSystemTrayItem available: %d",
              NSTouchBarItem.responds(to: NSSelectorFromString("addSystemTrayItem:")) ? 1 : 0)
        NSTouchBarItem.addSystemTrayItem(item)
        NSLog("EinsteinCat: addSystemTrayItem called")
        setPresence(ControlStripCat.identifier.rawValue as CFString, true)
        NSLog("EinsteinCat: control-strip presence enabled")
    }

    /// Quita el gatito (al cerrar la app).
    func hide() {
        setPresence?(ControlStripCat.identifier.rawValue as CFString, false)
        NSTouchBarItem.removeSystemTrayItem(item)
    }

    @objc private func tapped(_ sender: NSButton) {
        NSLog("EinsteinCat: Touch Bar cat tapped")
        DispatchQueue.main.async { [weak self] in
            self?.onTap()
        }
    }

    private func setupModalTouchBar() {
        modalTouchBar.delegate = self
        modalTouchBar.defaultItemIdentifiers = [ControlStripCat.modalItemIdentifier]
        modalTouchBar.customizationAllowedItemIdentifiers = []
        modalRunnerView.translatesAutoresizingMaskIntoConstraints = false
        modalRunnerView.widthAnchor.constraint(equalToConstant: 1000).isActive = true
        modalRunnerView.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let container = NSStackView(views: [modalRunnerView])
        container.orientation = .horizontal
        container.alignment = .centerY
        container.translatesAutoresizingMaskIntoConstraints = false
        modalItem.view = container
    }

    /// DFRFoundation no existe como archivo en disco (vive en la caché compartida de dyld),
    /// así que no se puede enlazar al compilar: se carga en tiempo de ejecución.
    private static func loadSetPresence() -> SetControlStripPresence? {
        let path = "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            NSLog("EinsteinCat: dlopen failed: %@", String(cString: dlerror()))
            return nil
        }

        guard let symbol = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") else {
            NSLog("EinsteinCat: dlsym failed: %@", String(cString: dlerror()))
            return nil
        }
        NSLog("EinsteinCat: DFRFoundation cargado")
        // Convertir el puntero "crudo" a una función C con la firma de arriba.
        return unsafeBitCast(symbol, to: SetControlStripPresence.self)
    }

    private static func loadSetCloseBoxVisibility() -> SetCloseBoxVisibility? {
        let path = "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            NSLog("EinsteinCat: could not load DFRFoundation for the modal close box")
            return nil
        }
        guard let symbol = dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost") else {
            NSLog("EinsteinCat: DFRSystemModalShowsCloseBoxWhenFrontMost was not found")
            return nil
        }
        return unsafeBitCast(symbol, to: SetCloseBoxVisibility.self)
    }
}

private final class TouchBarRunnerView: NSView {
    private let imageView = NSImageView()
    private var image: NSImage?
    private var imageX: CGFloat = 0
    var motionStep: CGFloat = 6

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 1000, height: 30)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
    }

    func setImage(_ image: NSImage) {
        if let copy = image.copy() as? NSImage {
            copy.isTemplate = false
            self.image = copy
        } else {
            self.image = image
        }
        imageView.image = self.image
        layoutImage()
        needsDisplay = true
    }

    func startPosition() {
        imageX = 0
        layoutImage()
        needsDisplay = true
    }

    func advance() {
        guard let image else { return }
        imageX += motionStep
        let imageWidth = image.size.width
        let availableWidth = max(bounds.width, intrinsicContentSize.width)
        if imageX > availableWidth {
            imageX = -imageWidth
        }
        layoutImage()
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        layoutImage()
    }

    private func layoutImage() {
        guard let image else { return }
        imageView.frame = NSRect(
            x: imageX,
            y: max(0, (bounds.height - image.size.height) / 2),
            width: image.size.width,
            height: image.size.height
        )
    }
}

extension ControlStripCat: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        NSLog("EinsteinCat: Touch Bar requested item %@", identifier.rawValue)
        guard identifier == ControlStripCat.modalItemIdentifier else { return nil }
        return modalItem
    }
}
