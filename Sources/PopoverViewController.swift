/*
 PopoverViewController.swift
 EinsteinCat

 Controlador de la ventana flotante (NSPopover).
 Incluye gráfica de CPU, memoria RAM, almacenamiento, energía, red y tabla virtualizada con scroll
 y buscador para ver y controlar TODOS los procesos activos de macOS.
*/

import Cocoa

final class PopoverViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let titleLabel = NSTextField(labelWithString: "EinsteinCat")
    private let subtitleLabel = NSTextField(labelWithString: "Hardware Monitor")
    private let installButton = NSButton()
    private let quitButton = NSButton()
    private let separator1 = NSBox()

    // 1. Sección CPU
    private let cpuSectionLabel = NSTextField(labelWithString: "CPU USAGE")
    private let cpuPercentLabel = NSTextField(labelWithString: "0.0%")
    private let cpuBreakdownLabel = NSTextField(labelWithString: "User: 0.0%  •  System: 0.0%")
    private let chartView = CPUChartView(frame: .zero)

    // 2. Sección Memoria RAM
    private let separator2 = NSBox()
    private let ramSectionLabel = NSTextField(labelWithString: "MEMORY")
    private let ramUsageLabel = NSTextField(labelWithString: "0.0 GB / 16.0 GB (0.0%)")
    private let ramBarView = RAMBarView(frame: .zero)
    private let memoryChartView = CPUChartView(frame: .zero)
    private let ramBreakdownLabel = NSTextField(labelWithString: "Apps: 0.0 GB  •  Wired: 0.0 GB  •  Comp: 0.0 GB")

    // 3. Secciones de almacenamiento, energía y red
    private let diskSectionLabel = NSTextField(labelWithString: "DISK")
    private let diskInfoLabel = NSTextField(labelWithString: "Loading storage...")
    private let diskChartView = DiskUsageChartView(frame: .zero)
    private let powerSectionLabel = NSTextField(labelWithString: "POWER")
    private let powerInfoLabel = NSTextField(labelWithString: "Loading power...")
    private let networkSectionLabel = NSTextField(labelWithString: "NETWORK")
    private let networkInfoLabel = NSTextField(labelWithString: "Loading network...")
    private let networkChartView = DualMetricChartView(frame: .zero)

    // 4. Sección Todas las Tareas / Procesos
    private let separator3 = NSBox()
    private let tasksSectionLabel = NSTextField(labelWithString: "ALL PROCESSES")
    private let searchField = NSSearchField()

    private let taskHeaderName = NSTextField(labelWithString: "PROCESS")
    private let taskHeaderPid = NSTextField(labelWithString: "PID")
    private let taskHeaderCpu = NSTextField(labelWithString: "CPU")
    private let taskHeaderRam = NSTextField(labelWithString: "MEMORY")
    private let taskHeaderKill = NSTextField(labelWithString: "CTRL")

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    private var allTasks: [ProcessTask] = []
    private var filteredTasks: [ProcessTask] = []
    private var filterQuery: String = ""
    private var memoryHistory: [Double] = []

    // 5. Pie informativo
    private let footerLabel = NSTextField(labelWithString: "Scroll to see all processes • Press ✕ to control")

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 720))
        container.wantsLayer = true
        self.view = container

        // --- Cabecera ---
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 16, y: 684, width: 180, height: 20)
        container.addSubview(titleLabel)

        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 16, y: 666, width: 180, height: 16)
        container.addSubview(subtitleLabel)

        let isAlreadyInstalled = Bundle.main.bundleURL.path.hasPrefix("/Applications")
        installButton.title = isAlreadyInstalled ? "✓ Installed" : "Install"
        installButton.isEnabled = !isAlreadyInstalled
        installButton.bezelStyle = .rounded
        installButton.font = NSFont.systemFont(ofSize: 11)
        installButton.toolTip = isAlreadyInstalled ? "EinsteinCat is installed in /Applications" : "Install EinsteinCat in /Applications"
        installButton.target = self
        installButton.action = #selector(installAppToApplications)
        installButton.frame = NSRect(x: 570, y: 676, width: 96, height: 26)
        container.addSubview(installButton)

        quitButton.title = "Quit"
        quitButton.bezelStyle = .rounded
        quitButton.font = NSFont.systemFont(ofSize: 11)
        quitButton.target = self
        quitButton.action = #selector(quitApp)
        quitButton.frame = NSRect(x: 676, y: 676, width: 68, height: 26)
        container.addSubview(quitButton)

        separator1.boxType = .separator
        separator1.frame = NSRect(x: 16, y: 650, width: 728, height: 1)
        container.addSubview(separator1)

        // --- 1. Sección CPU ---
        cpuSectionLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        cpuSectionLabel.textColor = .secondaryLabelColor
        cpuSectionLabel.frame = NSRect(x: 16, y: 628, width: 340, height: 14)
        container.addSubview(cpuSectionLabel)

        cpuPercentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        cpuPercentLabel.textColor = NSColor(red: 0.20, green: 0.78, blue: 0.96, alpha: 1.0)
        cpuPercentLabel.frame = NSRect(x: 16, y: 604, width: 85, height: 24)
        container.addSubview(cpuPercentLabel)

        cpuBreakdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        cpuBreakdownLabel.textColor = .secondaryLabelColor
        cpuBreakdownLabel.frame = NSRect(x: 105, y: 608, width: 260, height: 16)
        container.addSubview(cpuBreakdownLabel)

        chartView.frame = NSRect(x: 16, y: 518, width: 350, height: 82)
        container.addSubview(chartView)

        // --- 2. Sección Memoria RAM ---
        separator2.boxType = .separator
        separator2.frame = NSRect(x: 16, y: 506, width: 350, height: 1)
        container.addSubview(separator2)

        ramSectionLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        ramSectionLabel.textColor = .secondaryLabelColor
        ramSectionLabel.frame = NSRect(x: 16, y: 486, width: 350, height: 14)
        container.addSubview(ramSectionLabel)

        ramUsageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        ramUsageLabel.textColor = .labelColor
        ramUsageLabel.frame = NSRect(x: 16, y: 464, width: 350, height: 18)
        container.addSubview(ramUsageLabel)

        ramBarView.frame = NSRect(x: 16, y: 448, width: 350, height: 10)
        container.addSubview(ramBarView)

        ramBreakdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        ramBreakdownLabel.textColor = .secondaryLabelColor
        ramBreakdownLabel.frame = NSRect(x: 16, y: 428, width: 350, height: 16)
        container.addSubview(ramBreakdownLabel)
        memoryChartView.frame = NSRect(x: 16, y: 330, width: 350, height: 88)
        container.addSubview(memoryChartView)

        // --- 3. Almacenamiento, energía y red ---
        configureMetricSection(diskSectionLabel, title: "DISK", frame: NSRect(x: 400, y: 628, width: 340, height: 14), in: container)
        configureMetricValue(diskInfoLabel, frame: NSRect(x: 400, y: 510, width: 340, height: 36), in: container)
        diskChartView.frame = NSRect(x: 400, y: 548, width: 340, height: 58)
        container.addSubview(diskChartView)
        configureMetricSection(powerSectionLabel, title: "POWER", frame: NSRect(x: 400, y: 486, width: 340, height: 14), in: container)
        configureMetricValue(powerInfoLabel, frame: NSRect(x: 400, y: 446, width: 340, height: 32), in: container)
        configureMetricSection(networkSectionLabel, title: "NETWORK", frame: NSRect(x: 400, y: 384, width: 340, height: 14), in: container)
        configureMetricValue(networkInfoLabel, frame: NSRect(x: 400, y: 300, width: 340, height: 16), in: container)
        networkChartView.frame = NSRect(x: 400, y: 320, width: 340, height: 58)
        networkChartView.maxValue = 10
        container.addSubview(networkChartView)

        // --- 4. Sección Todas las Tareas / Procesos ---
        separator3.boxType = .separator
        separator3.frame = NSRect(x: 16, y: 270, width: 728, height: 1)
        container.addSubview(separator3)

        tasksSectionLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        tasksSectionLabel.textColor = .secondaryLabelColor
        tasksSectionLabel.frame = NSRect(x: 16, y: 250, width: 300, height: 14)
        container.addSubview(tasksSectionLabel)

        // Buscador
        searchField.placeholderString = "Search by name or PID..."
        searchField.font = NSFont.systemFont(ofSize: 11)
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.frame = NSRect(x: 16, y: 220, width: 728, height: 22)
        container.addSubview(searchField)

        // Encabezados de columna
        let headerFont = NSFont.systemFont(ofSize: 8, weight: .semibold)
        let headerColor = NSColor.secondaryLabelColor.withAlphaComponent(0.7)

        taskHeaderName.font = headerFont
        taskHeaderName.textColor = headerColor
        taskHeaderName.frame = NSRect(x: 22, y: 204, width: 260, height: 12)
        container.addSubview(taskHeaderName)

        taskHeaderPid.font = headerFont
        taskHeaderPid.textColor = headerColor
        taskHeaderPid.frame = NSRect(x: 330, y: 204, width: 60, height: 12)
        container.addSubview(taskHeaderPid)

        taskHeaderCpu.font = headerFont
        taskHeaderCpu.textColor = headerColor
        taskHeaderCpu.alignment = .right
        taskHeaderCpu.frame = NSRect(x: 470, y: 204, width: 70, height: 12)
        container.addSubview(taskHeaderCpu)

        taskHeaderRam.font = headerFont
        taskHeaderRam.textColor = headerColor
        taskHeaderRam.alignment = .right
        taskHeaderRam.frame = NSRect(x: 570, y: 204, width: 70, height: 12)
        container.addSubview(taskHeaderRam)

        taskHeaderKill.font = headerFont
        taskHeaderKill.textColor = headerColor
        taskHeaderKill.alignment = .center
        taskHeaderKill.frame = NSRect(x: 690, y: 204, width: 40, height: 12)
        container.addSubview(taskHeaderKill)

        // Tabla con ScrollView
        setupTableView()
        scrollView.frame = NSRect(x: 16, y: 32, width: 728, height: 160)
        container.addSubview(scrollView)

        // --- 4. Pie informativo ---
        footerLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        footerLabel.textColor = .tertiaryLabelColor
        footerLabel.alignment = .center
        footerLabel.frame = NSRect(x: 16, y: 8, width: 728, height: 18)
        container.addSubview(footerLabel)
    }

    private func configureMetricSection(_ label: NSTextField, title: String, frame: NSRect, in container: NSView) {
        label.stringValue = title
        label.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        label.textColor = .secondaryLabelColor
        label.frame = frame
        container.addSubview(label)
    }

    private func configureMetricValue(_ label: NSTextField, frame: NSRect, in container: NSView) {
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 4
        label.frame = frame
        container.addSubview(label)
    }

    private func setupTableView() {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ProcessCol"))
        column.width = 296
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 25
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 3)
        tableView.selectionHighlightStyle = .none
        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
    }

    // MARK: - NSTableViewDataSource & Delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredTasks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredTasks.count else { return nil }
        let cellIdentifier = NSUserInterfaceItemIdentifier("TaskRowCell")
        let rowView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? TaskRowView ?? TaskRowView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 25))
        rowView.identifier = cellIdentifier

        let task = filteredTasks[row]
        rowView.update(task: task)
        rowView.onKillClicked = { [weak self] t in
            self?.confirmKill(task: t)
        }
        return rowView
    }

    // MARK: - Búsqueda y Actualización
    @objc private func searchChanged() {
        filterQuery = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        applyFilter()
        tableView.reloadData()
    }

    func controlTextDidChange(_ obj: Notification) {
        searchChanged()
    }

    private func applyFilter() {
        if filterQuery.isEmpty {
            filteredTasks = allTasks
        } else {
            filteredTasks = allTasks.filter {
                $0.name.lowercased().contains(filterQuery) || String($0.pid).contains(filterQuery)
            }
        }
    }

    func updateCPU(info: CPUInfo, history: [Double]) {
        cpuPercentLabel.stringValue = String(format: "%4.1f%%", info.value)
        let loads = info.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " / ")
        cpuBreakdownLabel.stringValue = String(
            format: "User: %4.1f%%  •  System: %4.1f%%  •  Load %@  •  %d cores",
            info.user,
            info.system,
            loads,
            info.coreUsage.count
        )
        chartView.history = history
    }

    func updateRAM(info: RAMInfo) {
        let usedStr = String(format: "%.1f GB", info.usedGB)
        let totalStr = String(format: "%.1f GB", info.totalGB)
        let pctStr = String(format: "%.1f%%", info.percentage)
        ramUsageLabel.stringValue = "\(usedStr) / \(totalStr) (\(pctStr))"

        let appStr = String(format: "Apps: %.1f GB", info.appGB)
        let wiredStr = String(format: "Wired: %.1f GB", info.wiredGB)
        let compStr = String(format: "Compressed: %.1f GB", info.compressedGB)
        let swapStr = String(format: "Swap: %.1f / %.1f GB", info.swapUsedGB, info.swapTotalGB)
        ramBreakdownLabel.stringValue = "\(appStr)  •  \(wiredStr)  •  \(compStr)  •  \(swapStr)"

        ramBarView.info = info
        memoryHistory.append(info.percentage)
        if memoryHistory.count > memoryChartView.maxHistoryPoints {
            memoryHistory.removeFirst()
        }
        memoryChartView.history = memoryHistory
    }

    func updateSystemMetrics(_ info: SystemMetricsInfo) {
        if info.volumes.isEmpty {
            diskInfoLabel.stringValue = "Storage information unavailable"
        } else {
            let volumes = info.volumes.prefix(3).map { volume in
                let kind = volume.isInternal ? "Internal" : "External"
                return String(
                    format: "%@  %.0f GB used, %.0f GB free (%@)",
                    kind,
                    volume.usedGB,
                    volume.freeGB,
                    volume.name
                )
            }.joined(separator: "\n")
            diskInfoLabel.stringValue = "\(volumes)\nRead \(String(format: "%.2f", info.diskActivity.readMBps)) MB/s  •  Write \(String(format: "%.2f", info.diskActivity.writeMBps)) MB/s"
        }

        powerInfoLabel.stringValue = String(
            format: "%.0f%%  •  %@  •  %@",
            info.power.level,
            info.power.state,
            info.power.timeRemaining
        )
        networkInfoLabel.stringValue = String(
            format: "Down %.2f MB/s  •  Up %.2f MB/s",
            info.network.downloadMBps,
            info.network.uploadMBps
        )
        diskChartView.volumes = info.volumes
        networkChartView.primaryHistory.append(info.network.downloadMBps)
        networkChartView.secondaryHistory.append(info.network.uploadMBps)
        if networkChartView.primaryHistory.count > 30 {
            networkChartView.primaryHistory.removeFirst()
        }
        if networkChartView.secondaryHistory.count > 30 {
            networkChartView.secondaryHistory.removeFirst()
        }
    }

    func updateTasks(_ tasks: [ProcessTask]) {
        allTasks = tasks
        applyFilter()
        tableView.reloadData()
    }

    // MARK: - Control de Procesos y Alertas
    private func confirmKill(task: ProcessTask) {
        let alert = NSAlert()
        if let icon = NSApp.applicationIconImage ?? NSImage(named: "AppIcon") {
            alert.icon = icon
        }
        alert.messageText = "Control process \"\(task.name)\"?"

        var info = "PID: \(task.pid)  •  CPU: \(task.cpuFormatted)  •  RAM: \(task.memoryFormatted)"
        if ProcessKiller.isTelemetryOrBackground(name: task.name) {
            info += "\n\n⚠️ A telemetry/background process was detected. Pause/Freeze (SIGSTOP) stops it at 0% CPU without launchd restarting it."
        }
        alert.informativeText = info
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Terminate (SIGTERM)")
        alert.addButton(withTitle: "Pause/Freeze (SIGSTOP)")
        alert.addButton(withTitle: "Resume (SIGCONT)")
        alert.addButton(withTitle: "Force Quit (SIGKILL)")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        let signal: KillSignal?
        switch response {
        case .alertFirstButtonReturn:
            signal = .terminate
        case .alertSecondButtonReturn:
            signal = .suspend
        case .alertThirdButtonReturn:
            signal = .resume
        case NSApplication.ModalResponse(rawValue: 1003):
            signal = .forceQuit
        default:
            signal = nil
        }

        guard let chosenSignal = signal else { return }

        let result = ProcessKiller.killProcess(pid: task.pid, signal: chosenSignal)
        switch result {
        case .success:
            NSLog("EinsteinCat: sent %@ to %@ [%d]", chosenSignal.displayName, task.name, task.pid)
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.forceRefreshTasks()
            }
        case .permissionDenied:
            showNoticeAlert(
                title: "Permission denied by macOS",
                message: "Process \"\(task.name)\" (PID \(task.pid)) belongs to the system and is protected by macOS."
            )
        case .processNotFound:
            showNoticeAlert(
                title: "Process not found",
                message: "The process has already exited."
            )
        case .failed(let errno, let message):
            showNoticeAlert(
                title: "Process control error",
                message: "Error \(errno): \(message)"
            )
        }
    }

    @objc private func installAppToApplications() {
        let bundleURL = Bundle.main.bundleURL
        let targetURL = URL(fileURLWithPath: "/Applications/EinsteinCat.app")

        if bundleURL.path.hasPrefix("/Applications") {
            installButton.title = "✓ Installed"
            installButton.isEnabled = false
            showNoticeAlert(
                title: "Already installed",
                message: "EinsteinCat is already installed and running from /Applications."
            )
            return
        }

        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: bundleURL, to: targetURL)
            installButton.title = "✓ Installed"
            installButton.isEnabled = false
            showNoticeAlert(
                title: "Installation successful",
                message: "EinsteinCat was installed in /Applications. You can launch it from Spotlight or Launchpad."
            )
        } catch {
            showNoticeAlert(
                title: "Installation failed",
                message: "Could not copy EinsteinCat to /Applications: \(error.localizedDescription)"
            )
        }
    }

    private func showNoticeAlert(title: String, message: String) {
        let alert = NSAlert()
        if let icon = NSApp.applicationIconImage ?? NSImage(named: "AppIcon") {
            alert.icon = icon
        }
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Entendido")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
