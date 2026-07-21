import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate {
    private var welcomeWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var tutorPanel: NSPanel?
    private var statusItem: NSStatusItem?
    private var hotKey: HotKeyManager?
    private var observer: NSObjectProtocol?
    private var escapeMonitor: Any?
    private var permissionRefreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installApplicationIcon()
        createWelcomeWindow()
        createTutorPanel()
        createStatusItem()
        hotKey = HotKeyManager()

        let model = TutorModel.shared
        model.onShowPanel = { [weak self] in self?.showTutorPanel() }
        model.onHidePanel = { [weak self] in self?.tutorPanel?.orderOut(nil) }
        model.onShowWelcome = { [weak self] in self?.showWelcome() }
        model.onShowSettings = { [weak self] pane in self?.showSettings(pane) }
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
    }

    func applicationDidBecomeActive(_ notification: Notification) {
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
        window.title = "Aster✱"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isRestorable = false
        window.contentViewController = controller
        window.sharingType = .none
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
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 720),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = NSHostingController(rootView: view)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isRestorable = false
        panel.sharingType = .none
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
            window.sharingType = .none
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
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.maxX - panel.frame.width - 22, y: visible.minY + 24))
        panel.orderFrontRegardless()
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
