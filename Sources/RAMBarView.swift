/*
 RAMBarView.swift
 EinsteinCat

 Barra visual segmentada para representar la memoria RAM.
 Fase C: Desglose proporcional de Apps (Azul), Wired (Púrpura) y Comprimida (Ámbar).
*/

import Cocoa

final class RAMBarView: NSView {
    var info: RAMInfo = RAMInfo.default {
        didSet {
            needsDisplay = true
        }
    }

    private let appColor = NSColor(red: 0.20, green: 0.65, blue: 0.95, alpha: 1.0)        // Azul Apps
    private let wiredColor = NSColor(red: 0.68, green: 0.42, blue: 0.95, alpha: 1.0)      // Púrpura Wired
    private let compressedColor = NSColor(red: 0.98, green: 0.68, blue: 0.18, alpha: 1.0) // Ámbar Comprimida

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1.0
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard info.totalBytes > 0 else { return }

        let total = CGFloat(info.totalBytes)
        let width = bounds.width
        let height = bounds.height

        let appW = (CGFloat(info.appBytes) / total) * width
        let wiredW = (CGFloat(info.wiredBytes) / total) * width
        let compW = (CGFloat(info.compressedBytes) / total) * width

        var currentX: CGFloat = 0

        // 1. Memoria de Aplicaciones (Activa)
        if appW > 0 {
            appColor.setFill()
            NSRect(x: currentX, y: 0, width: appW, height: height).fill()
            currentX += appW
        }

        // 2. Memoria del Sistema / Wired (Fijada)
        if wiredW > 0 {
            wiredColor.setFill()
            NSRect(x: currentX, y: 0, width: wiredW, height: height).fill()
            currentX += wiredW
        }

        // 3. Memoria Comprimida
        if compW > 0 {
            compressedColor.setFill()
            NSRect(x: currentX, y: 0, width: compW, height: height).fill()
        }
    }
}
