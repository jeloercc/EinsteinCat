/*
 AppDelegate.swift
 Menubar RunCat

 Created by Takuto Nakamura on 2019/08/06.
 Copyright © 2019 Takuto Nakamura. All rights reserved.

 Modificado para EinsteinCat:
 - Las imágenes se marcan como template (antes lo hacía el .xcassets).
 - Gatito en la tira de control de la Touch Bar (ControlStripCat).
*/

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private lazy var statusItem: NSStatusItem = {
        return NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()
    private let menu = NSMenu()
    private lazy var frames: [NSImage] = {
        return (0 ..< 5).map { n in
            let image = NSImage(named: "cat_page\(n)")!
            image.size = NSSize(width: 28, height: 18)
            image.isTemplate = true
            return image
        }
    }()
    private var index: Int = 0
    private var interval: Double = 1.0
    private let cpu = CPU()
    private let ram = RAM()
    private let systemMetrics = SystemMetrics()
    private let processMonitor = ProcessMonitor()
    private var usage: CPUInfo = CPU.default
    private var cpuTimer: Timer? = nil
    private var runnerTimer: Timer? = nil
    private var popoverFastTimer: Timer? = nil
    private var isShowUsage: Bool = false
    private var controlStripCat: ControlStripCat? = nil
    private let popover = NSPopover()
    private let popoverVC = PopoverViewController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }
        setupPopover()
        setupStatusItem()
        setNotifications()
        controlStripCat = ControlStripCat(image: frames[0]) { [weak self] in
            self?.toggleTouchBar()
        }
        controlStripCat?.show()
        startRunning()
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentViewController = popoverVC
        popover.delegate = self
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopRunning()
        controlStripCat?.dismissModal()
        controlStripCat?.hide()
    }

    private func updateUsageDescription() {
        statusItem.button?.title = isShowUsage ? usage.description : ""
    }

    @objc func toggleShowUsage(_ sender: NSMenuItem) {
        isShowUsage = (sender.state == .off)
        sender.state = isShowUsage ? .on : .off
        updateUsageDescription()
    }

    @objc func openAbout(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func terminateApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageTrailing
        button.image = frames.first
        if #available(macOS 10.15, *) {
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            button.font = font
        } else {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            button.font = font
        }

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        menu.addItem(withTitle: "Show CPU Usage",
                     action: #selector(toggleShowUsage(_:)),
                     keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "About EinsteinCat",
                     action: #selector(openAbout(_:)),
                     keyEquivalent: "")
        menu.addItem(withTitle: "Quit EinsteinCat",
                     action: #selector(terminateApp(_:)),
                     keyEquivalent: "")
    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control)) {
            // Clic derecho o Control+clic: mostrar menú clásico
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
        } else {
            // Clic izquierdo: abrir o cerrar la ventana flotante
            togglePopover(sender)
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popoverVC.updateCPU(info: usage, history: cpu.history)
            popoverVC.updateRAM(info: ram.currentUsage())
            popoverVC.updateSystemMetrics(systemMetrics.current())
            popoverVC.updateTasks(processMonitor.allProcesses())
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidShow(_ notification: Notification) {
        startFastSampling()
    }

    func popoverDidClose(_ notification: Notification) {
        stopFastSampling()
    }

    private func startFastSampling() {
        updateUsage()
        popoverFastTimer?.invalidate()
        popoverFastTimer = Timer(timeInterval: 1.0, repeats: true, block: { [weak self] _ in
            self?.updateUsage()
        })
        RunLoop.main.add(popoverFastTimer!, forMode: .common)
    }

    private func stopFastSampling() {
        popoverFastTimer?.invalidate()
        popoverFastTimer = nil
    }

    @objc func receiveSleep(_ notification: NSNotification) {
        stopRunning()
    }

    @objc func receiveWakeUp(_ notification: NSNotification) {
        startRunning()
    }

    private func setNotifications() {
        NSWorkspace.shared.notificationCenter
            .addObserver(self, selector: #selector(receiveSleep(_:)),
                         name: NSWorkspace.willSleepNotification,
                         object: nil)
        NSWorkspace.shared.notificationCenter
            .addObserver(self, selector: #selector(receiveWakeUp(_:)),
                         name: NSWorkspace.didWakeNotification,
                         object: nil)
    }

    private func updateUsage() {
        usage = cpu.currentUsage()
        controlStripCat?.setMotionSpeed(forCPU: usage)
        interval = 0.2 / max(1.0, min(20.0, self.usage.value / 5.0))
        updateUsageDescription()
        runnerTimer?.invalidate()
        runnerTimer = Timer(timeInterval: self.interval, repeats: true, block: { [weak self] _ in
            self?.next()
        })
        RunLoop.main.add(runnerTimer!, forMode: .common)

        if popover.isShown {
            popoverVC.updateCPU(info: usage, history: cpu.history)
            popoverVC.updateRAM(info: ram.currentUsage())
            popoverVC.updateSystemMetrics(systemMetrics.current())
            popoverVC.updateTasks(processMonitor.allProcesses())
        }
    }

    func forceRefreshTasks() {
        popoverVC.updateTasks(processMonitor.allProcesses())
    }

    private func next() {
        index = (index + 1) % frames.count
        statusItem.button?.image = frames[index]
        controlStripCat?.setFrame(frames[index])
    }

    private func toggleTouchBar() {
        controlStripCat?.presentModal()
    }

    private func startRunning() {
        cpuTimer = Timer(timeInterval: 5.0, repeats: true, block: { [weak self] _ in
            self?.updateUsage()
        })
        RunLoop.main.add(cpuTimer!, forMode: .common)
        cpuTimer?.fire()
    }
    
    private func stopRunning() {
        controlStripCat?.dismissModal()
        runnerTimer?.invalidate()
        cpuTimer?.invalidate()
        popoverFastTimer?.invalidate()
    }
}
