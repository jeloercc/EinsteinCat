/*
 TaskRowView.swift
 EinsteinCat

 Fila para mostrar un proceso en la lista completa de tareas.
 Diseño responsivo que se adapta al ancho de la tabla y a la presencia de barras de scroll.
*/

import Cocoa

final class TaskRowView: NSView {
    var onKillClicked: ((ProcessTask) -> Void)?

    private var currentTask: ProcessTask?
    private let nameLabel = NSTextField(labelWithString: "—")
    private let pidLabel = NSTextField(labelWithString: "—")
    private let cpuLabel = NSTextField(labelWithString: "0.0%")
    private let ramLabel = NSTextField(labelWithString: "0 MB")
    private let killButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.12).cgColor

        // Nombre del proceso
        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)

        // PID
        pidLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        pidLabel.textColor = .secondaryLabelColor
        addSubview(pidLabel)

        // CPU %
        cpuLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        cpuLabel.textColor = NSColor(red: 0.20, green: 0.78, blue: 0.96, alpha: 1.0)
        cpuLabel.alignment = .right
        addSubview(cpuLabel)

        // RAM
        ramLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        ramLabel.textColor = .secondaryLabelColor
        ramLabel.alignment = .right
        addSubview(ramLabel)

        // Botón Terminar (✕)
        killButton.title = "✕"
        killButton.bezelStyle = .inline
        killButton.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        killButton.toolTip = "Controlar este proceso"
        killButton.target = self
        killButton.action = #selector(killTapped)
        addSubview(killButton)

        layoutViews()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutViews()
    }

    override func layout() {
        super.layout()
        layoutViews()
    }

    private func layoutViews() {
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }

        killButton.frame = NSRect(x: w - 28, y: (h - 19) / 2, width: 24, height: 19)
        ramLabel.frame = NSRect(x: w - 80, y: (h - 18) / 2, width: 50, height: 18)
        cpuLabel.frame = NSRect(x: w - 128, y: (h - 18) / 2, width: 46, height: 18)
        pidLabel.frame = NSRect(x: w - 172, y: (h - 18) / 2, width: 42, height: 18)
        
        let nameW = max(50, w - 178)
        nameLabel.frame = NSRect(x: 6, y: (h - 18) / 2, width: nameW, height: 18)
    }

    func update(task: ProcessTask) {
        self.currentTask = task
        nameLabel.stringValue = task.name
        pidLabel.stringValue = "\(task.pid)"
        cpuLabel.stringValue = task.cpuFormatted
        ramLabel.stringValue = task.memoryFormatted
        killButton.isHidden = false
    }

    func clear() {
        self.currentTask = nil
        nameLabel.stringValue = "—"
        pidLabel.stringValue = ""
        cpuLabel.stringValue = "—"
        ramLabel.stringValue = "—"
        killButton.isHidden = true
    }

    @objc private func killTapped() {
        guard let task = currentTask else { return }
        onKillClicked?(task)
    }
}
