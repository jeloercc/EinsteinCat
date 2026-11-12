/*
 MetricChartViews.swift
 EinsteinCat

 Compact charts for memory, disk, and network metrics.
*/

import Cocoa

final class DualMetricChartView: NSView {
    var primaryHistory: [Double] = [] { didSet { needsDisplay = true } }
    var secondaryHistory: [Double] = [] { didSet { needsDisplay = true } }
    var maxValue: Double = 1 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let plot = bounds.insetBy(dx: 8, dy: 8)
        guard plot.width > 10, plot.height > 10 else { return }

        NSColor.black.withAlphaComponent(0.25).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()

        let grid = NSColor.textColor.withAlphaComponent(0.12)
        for fraction in [0.0, 0.5, 1.0] {
            let y = plot.minY + plot.height * fraction
            let path = NSBezierPath()
            path.move(to: NSPoint(x: plot.minX, y: y))
            path.line(to: NSPoint(x: plot.maxX, y: y))
            path.lineWidth = 0.5
            grid.setStroke()
            path.stroke()
        }

        drawLine(primaryHistory, color: NSColor.systemGreen, in: plot)
        drawLine(secondaryHistory, color: NSColor.systemOrange, in: plot)
    }

    private func drawLine(_ values: [Double], color: NSColor, in plot: NSRect) {
        guard values.count > 1, maxValue > 0 else { return }
        let path = NSBezierPath()
        let step = plot.width / CGFloat(max(1, values.count - 1))
        for (index, value) in values.enumerated() {
            let x = plot.minX + CGFloat(index) * step
            let y = plot.minY + plot.height * CGFloat(max(0, min(maxValue, value)) / maxValue)
            if index == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        color.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
}

final class DiskUsageChartView: NSView {
    var volumes: [DiskVolumeInfo] = [] { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let rows = volumes.prefix(3)
        guard !rows.isEmpty else { return }

        let rowHeight: CGFloat = min(20, bounds.height / CGFloat(rows.count))
        for (index, volume) in rows.enumerated() {
            let y = bounds.height - CGFloat(index + 1) * rowHeight + 3
            let label = "\(volume.isInternal ? "Internal" : "External")  \(volume.name)"
            (label as NSString).draw(
                at: NSPoint(x: 0, y: y + 4),
                withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.labelColor]
            )

            let barX: CGFloat = 135
            let barWidth = max(40, bounds.width - barX)
            let barRect = NSRect(x: barX, y: y + 4, width: barWidth, height: 9)
            NSColor.black.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: barRect, xRadius: 4, yRadius: 4).fill()

            let used = CGFloat(volume.usedGB / max(volume.totalGB, 1))
            NSColor.systemBlue.setFill()
            NSBezierPath(
                roundedRect: NSRect(x: barX, y: y + 4, width: barWidth * used, height: 9),
                xRadius: 4,
                yRadius: 4
            ).fill()
        }
    }
}
