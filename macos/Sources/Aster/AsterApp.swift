import AppKit
import QuartzCore
import SwiftUI

extension Notification.Name {
    static let asterFocusComposer = Notification.Name("AsterFocusComposer")
}

/// Aster✱ overlays must accept typing without activating the application or
/// pulling the learner away from the Space that contains their source material.
final class AsterKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum TutorPanelConfiguration {
    static let styleMask: NSWindow.StyleMask = [.borderless, .fullSizeContentView, .nonactivatingPanel]
    static let collectionBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate {
    private var welcomeWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var tutorPanel: NSPanel?
    private var statusItem: NSStatusItem?
    private var hotKey: HotKeyManager?
    private var observer: NSObjectProtocol?
    private var escapeMonitor: Any?
    private var externalPointerMonitor: Any?
    private var permissionRefreshTask: Task<Void, Never>?

    private let tutorPanelWidth: CGFloat = 1_080
    private let tutorPanelCollapsedHeight: CGFloat = 140
    private let tutorPanelExpandedHeight: CGFloat = 520

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installApplicationIcon()
        let model = TutorModel.shared
        model.onShowPanel = { [weak self] in self?.showTutorPanel() }
        model.onHidePanel = { [weak self] in self?.tutorPanel?.orderOut(nil) }
        model.onPanelExpansionChanged = { [weak self] expanded in self?.resizeTutorPanel(expanded: expanded) }
        model.onShowWelcome = { [weak self] in self?.showWelcome() }
        model.onShowSettings = { [weak self] pane in self?.showSettings(pane) }

        createWelcomeWindow()
        if !model.requiresApplicationRelocation {
            createTutorPanel()
            createStatusItem()
            hotKey = HotKeyManager()
        }

        observer = NotificationCenter.default.addObserver(forName: .asterHotKey, object: nil, queue: .main) { _ in
            Task { @MainActor in TutorModel.shared.activateFromHotKey() }
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53, TutorModel.shared.isPanelVisible {
                Task { @MainActor in TutorModel.shared.clearLesson() }
                return nil
            }
            return event
        }
        externalPointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor in TutorModel.shared.updateExternalPointer(point) }
        }
    }

    private func installApplicationIcon() {
        guard
            let iconURL = Bundle.main.url(forResource: "Aster", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else { return }

        icon.isTemplate = false
        NSApp.applicationIconImage = icon
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionRefreshTask?.cancel()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        if let externalPointerMonitor { NSEvent.removeMonitor(externalPointerMonitor) }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !TutorModel.shared.requiresApplicationRelocation else { return }
        permissionRefreshTask?.cancel()
        TutorModel.shared.refreshPermissionStatuses()
        permissionRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            TutorModel.shared.refreshPermissionStatuses()
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            TutorModel.shared.refreshPermissionStatuses()
        }
    }

    private func createWelcomeWindow() {
        let view = WelcomeView(model: TutorModel.shared)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_080, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = TutorModel.shared.requiresApplicationRelocation ? "Aster✱ — Move to Applications" : "Aster✱"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isRestorable = false
        window.contentViewController = controller
        window.sharingType = .readOnly
        window.minSize = NSSize(width: 1_040, height: 720)
        if let screen = NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createTutorPanel() {
        let view = TutorPanelView(model: TutorModel.shared)
        let panel = AsterKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: tutorPanelWidth, height: tutorPanelCollapsedHeight),
            styleMask: TutorPanelConfiguration.styleMask,
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = NSHostingController(rootView: view)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = TutorPanelConfiguration.collectionBehavior
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isRestorable = false
        panel.sharingType = .readOnly
        tutorPanel = panel
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = AsterGlyphRenderer.menuBarImage()
        let menu = NSMenu()
        menu.addItem(withTitle: "Ask Aster✱  ⌥ Space", action: #selector(askAster), keyEquivalent: "")
        menu.addItem(withTitle: "Welcome", action: #selector(showWelcomeMenu), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(showSettingsMenu), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Aster✱", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func askAster() { TutorModel.shared.activateFromHotKey() }
    @objc private func showWelcomeMenu() { showWelcome() }
    @objc private func showSettingsMenu() { showSettings(TutorModel.shared.settingsPane) }

    private func showWelcome() {
        welcomeWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showSettings(_ pane: SettingsPane) {
        TutorModel.shared.settingsPane = pane
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(model: TutorModel.shared))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 680),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = controller
            window.isReleasedWhenClosed = false
            window.tabbingMode = .disallowed
            window.collectionBehavior = [.fullScreenNone]
            window.sharingType = .readOnly
            let toolbar = NSToolbar(identifier: "AsterSettingsToolbar")
            toolbar.delegate = self
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            toolbar.displayMode = .iconAndLabel
            toolbar.sizeMode = .regular
            window.toolbar = toolbar
            window.toolbarStyle = .preference
            window.center()
            settingsWindow = window
        }
        settingsWindow?.title = "\(pane.title) — Aster✱ Settings"
        settingsWindow?.toolbar?.selectedItemIdentifier = toolbarIdentifier(for: pane)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func toolbarIdentifier(for pane: SettingsPane) -> NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("aster.settings.\(pane.rawValue)")
    }

    private func pane(for identifier: NSToolbarItem.Identifier) -> SettingsPane? {
        SettingsPane.allCases.first { toolbarIdentifier(for: $0) == identifier }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPane.allCases.map(toolbarIdentifier)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let pane = pane(for: itemIdentifier) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = pane.title
        item.paletteLabel = pane.title
        item.toolTip = pane.subtitle
        item.image = NSImage(systemSymbolName: pane.systemImage, accessibilityDescription: pane.title)
        item.target = self
        item.action = #selector(selectSettingsPane(_:))
        return item
    }

    @objc private func selectSettingsPane(_ sender: NSToolbarItem) {
        guard let pane = pane(for: sender.itemIdentifier) else { return }
        TutorModel.shared.settingsPane = pane
        settingsWindow?.title = "\(pane.title) — Aster✱ Settings"
        settingsWindow?.toolbar?.selectedItemIdentifier = sender.itemIdentifier
    }

    private func showTutorPanel() {
        guard let panel = tutorPanel, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        if !panel.isVisible {
            let visible = screen.visibleFrame
            let width = min(tutorPanelWidth, visible.width - 32)
            let height = TutorModel.shared.isPanelExpanded ? tutorPanelExpandedHeight : tutorPanelCollapsedHeight
            let destination = NSRect(
                x: visible.midX - width / 2,
                y: visible.maxY - height - 16,
                width: width,
                height: height
            )
            panel.setFrame(destination.offsetBy(dx: 0, dy: height + 28), display: true)
            panel.alphaValue = 0.2
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.30
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(destination, display: true)
                panel.animator().alphaValue = 1
            } completionHandler: { [weak self, weak panel] in
                guard let self, let panel else { return }
                self.focusTutorPanel(panel)
            }
            return
        }
        panel.orderFrontRegardless()
        focusTutorPanel(panel)
    }

    private func focusTutorPanel(_ panel: NSPanel) {
        // A non-activating panel may become key while Chrome, Preview, or the
        // learner's full-screen app remains the active application.
        panel.makeKey()
        DispatchQueue.main.async { [weak panel] in
            panel?.makeKey()
            NotificationCenter.default.post(name: .asterFocusComposer, object: nil)
        }
    }

    private func resizeTutorPanel(expanded: Bool) {
        guard let panel = tutorPanel else { return }
        let oldFrame = panel.frame
        let newHeight = expanded ? tutorPanelExpandedHeight : tutorPanelCollapsedHeight
        guard abs(oldFrame.height - newHeight) > 1 else { return }
        let newFrame = NSRect(
            x: oldFrame.minX,
            y: oldFrame.maxY - newHeight,
            width: oldFrame.width,
            height: newHeight
        )
        panel.setFrame(newFrame, display: true, animate: panel.isVisible)
    }
}

@main
struct AsterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            SettingsView(model: TutorModel.shared)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { TutorModel.shared.showSettings() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
