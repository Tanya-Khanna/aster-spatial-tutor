import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var welcomeWindow: NSWindow?
    private var tutorPanel: NSPanel?
    private var statusItem: NSStatusItem?
    private var hotKey: HotKeyManager?
    private var observer: NSObjectProtocol?
    private var escapeMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        createWelcomeWindow()
        createTutorPanel()
        createStatusItem()
        hotKey = HotKeyManager()

        let model = TutorModel.shared
        model.onShowPanel = { [weak self] in self?.showTutorPanel() }
        model.onHidePanel = { [weak self] in self?.tutorPanel?.orderOut(nil) }
        model.onShowWelcome = { [weak self] in self?.showWelcome() }
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

    func applicationWillTerminate(_ notification: Notification) {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
    }

    private func createWelcomeWindow() {
        let view = WelcomeView(model: TutorModel.shared)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1020, height: 710),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Aster"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.contentViewController = controller
        window.sharingType = .none
        window.center()
        window.minSize = NSSize(width: 980, height: 680)
        window.makeKeyAndOrderFront(nil)
        welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createTutorPanel() {
        let view = TutorPanelView(model: TutorModel.shared)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 620),
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
        panel.sharingType = .none
        tutorPanel = panel
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = AsterGlyphRenderer.menuBarImage()
        let menu = NSMenu()
        menu.addItem(withTitle: "Ask Aster  ⌥ Space", action: #selector(askAster), keyEquivalent: "")
        menu.addItem(withTitle: "Welcome", action: #selector(showWelcomeMenu), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Aster", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func askAster() { TutorModel.shared.activateFromHotKey() }
    @objc private func showWelcomeMenu() { showWelcome() }

    private func showWelcome() {
        welcomeWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
            EmptyView()
        }
    }
}
