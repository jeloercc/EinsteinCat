/*
 CPUChartView.swift
 EinsteinCat

 Vista personalizada (NSView) para dibujar la gráfica de CPU en tiempo real.
 Fase B: Dibujo vectorial nativo con NSBezierPath y NSGradient.
*/

import Cocoa

final class CPUChartView: NSView {
    var history: [Double] = [] {
        didSet {
            needsDisplay = true
        }
    }
    var maxHistoryPoints: Int = 30

    private let strokeColor = NSColor(red: 0.20, green: 0.78, blue: 0.96, alpha: 1.0) // Azul/Cian brillante
    private let gradientStart = NSColor(red: 0.20, green: 0.78, blue: 0.96, alpha: 0.35)
    private let gradientEnd = NSColor(red: 0.20, green: 0.78, blue: 0.96, alpha: 0.02)
    private let gridColor = NSColor.textColor.withAlphaComponent(0.12)
    private let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
        .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.7)
    ]

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
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1.0
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let topPadding: CGFloat = 8
        let bottomPadding: CGFloat = 8
        let leftPadding: CGFloat = 8
        let rightPadding: CGFloat = 36 // Espacio para las etiquetas de porcentaje
        
        let plotWidth = bounds.width - leftPadding - rightPadding
        let plotHeight = bounds.height - topPadding - bottomPadding

        guard plotWidth > 10, plotHeight > 10 else { return }

        // 1. Dibujar líneas de guía horizontales (100%, 50%, 0%)
        let gridPercentages: [CGFloat] = [0.0, 0.5, 1.0]
        for pct in gridPercentages {
            let y = bottomPadding + pct * plotHeight
            
            let gridPath = NSBezierPath()
            gridPath.move(to: NSPoint(x: leftPadding, y: y))
            gridPath.line(to: NSPoint(x: leftPadding + plotWidth, y: y))
            gridPath.lineWidth = 0.5
            gridColor.setStroke()
            gridPath.stroke()

            // Texto de porcentaje al margen derecho
            let labelText = String(format: "%3.0f%%", pct * 100)
            let textPoint = NSPoint(x: leftPadding + plotWidth + 4, y: y - 5)
            (labelText as NSString).draw(at: textPoint, withAttributes: labelAttributes)
        }

        // 2. Trazar la curva de datos si hay historial
        guard history.count > 1 else { return }

        let stepX = plotWidth / CGFloat(max(1, maxHistoryPoints - 1))
        let startIndex = max(0, maxHistoryPoints - history.count)

        let linePath = NSBezierPath()
        var firstPoint = NSPoint.zero
        var lastPoint = NSPoint.zero

        for (i, val) in history.enumerated() {
            let clampedVal = max(0.0, min(100.0, val))
            let x = leftPadding + CGFloat(startIndex + i) * stepX
            let y = bottomPadding + (CGFloat(clampedVal) / 100.0) * plotHeight
            let point = NSPoint(x: x, y: y)

            if i == 0 {
                linePath.move(to: point)
                firstPoint = point
            } else {
                linePath.line(to: point)
            }
            lastPoint = point
        }

        // 3. Relleno con gradiente bajo la curva
        if let fillPath = linePath.copy() as? NSBezierPath {
            fillPath.line(to: NSPoint(x: lastPoint.x, y: bottomPadding))
            fillPath.line(to: NSPoint(x: firstPoint.x, y: bottomPadding))
            fillPath.close()

            let gradient = NSGradient(starting: gradientStart, ending: gradientEnd)
            gradient?.draw(in: fillPath, angle: 90)
        }

        // 4. Trazo nítido de la línea superior
        strokeColor.setStroke()
        linePath.lineWidth = 1.5
        linePath.lineJoinStyle = .round
        linePath.stroke()
    }
}
