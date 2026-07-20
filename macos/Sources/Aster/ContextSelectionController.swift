import AppKit

@MainActor
final class ContextSelectionController {
    private var panel: NSPanel?
    private var completion: ((CaptureTarget?) -> Void)?
    private var activeDisplayID: CGDirectDisplayID?

    func begin(completion: @escaping (CaptureTarget?) -> Void) {
        let cursor = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main,
              let displayID = ScreenCaptureService.displayID(for: screen) else { completion(nil); return }
        cancel()
        self.completion = completion
        self.activeDisplayID = displayID

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let view = ContextSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onComplete = { [weak self] region in
            guard let self, let displayID = self.activeDisplayID else { return }
            self.finish(.displayRegion(displayID: displayID, region: region))
        }
        view.onCancel = { [weak self] in self?.finish(nil) }
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.sharingType = .none
        panel.setFrame(screen.frame, display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    /// Selects the frontmost normal window under the pointer. The stable window
    /// number lets capture recover its new bounds after a move or resize.
    func selectWindowUnderCursor() -> CaptureTarget? {
        let point = CGEvent(source: nil)?.location ?? .zero
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for info in windows {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let owner = info[kCGWindowOwnerName as String] as? String,
                  owner != "Aster",
                  owner != "Aster✱",
                  let number = info[kCGWindowNumber as String] as? NSNumber,
                  let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                  bounds.contains(point), bounds.width > 120, bounds.height > 80 else { continue }
            guard let screen = NSScreen.screens.first(where: {
                guard let id = ScreenCaptureService.displayID(for: $0) else { return false }
                return CGDisplayBounds(id).intersects(bounds)
            }), let displayID = ScreenCaptureService.displayID(for: screen) else { continue }
            let displayBounds = CGDisplayBounds(displayID)
            let region = ContextRegion(
                x: (bounds.minX - displayBounds.minX) / displayBounds.width,
                y: (bounds.minY - displayBounds.minY) / displayBounds.height,
                width: bounds.width / displayBounds.width,
                height: bounds.height / displayBounds.height
            )
            return CaptureTarget(
                kind: .window,
                displayID: displayID,
                region: region,
                windowID: number.uint32Value,
                appName: owner,
                windowTitle: info[kCGWindowName as String] as? String ?? "Window",
                anchor: nil
            )
        }
        return nil
    }

    func cancel() {
        panel?.orderOut(nil)
        panel = nil
        completion = nil
        activeDisplayID = nil
    }

    private func finish(_ target: CaptureTarget?) {
        let callback = completion
        panel?.orderOut(nil)
        panel = nil
        completion = nil
        activeDisplayID = nil
        callback?(target)
    }
}

private final class ContextSelectionView: NSView {
    var onComplete: ((ContextRegion) -> Void)?
    var onCancel: (() -> Void)?
    private var startPoint: NSPoint?
    private var selection = NSRect.zero

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selection = NSRect(origin: startPoint!, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        selection = NSRect(
            x: min(startPoint.x, current.x),
            y: min(startPoint.y, current.y),
            width: abs(current.x - startPoint.x),
            height: abs(current.y - startPoint.y)
        ).intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let startPoint else { return }
        var chosen = selection
        if chosen.width < 24 || chosen.height < 24 {
            let size = NSSize(width: min(500, bounds.width * 0.44), height: min(330, bounds.height * 0.40))
            chosen = NSRect(
                x: min(max(startPoint.x - size.width / 2, 0), bounds.width - size.width),
                y: min(max(startPoint.y - size.height / 2, 0), bounds.height - size.height),
                width: size.width,
                height: size.height
            )
        }
        onComplete?(ContextRegion(
            x: chosen.minX / bounds.width,
            y: chosen.minY / bounds.height,
            width: chosen.width / bounds.width,
            height: chosen.height / bounds.height
        ))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.48).setFill()
        bounds.fill()

        if !selection.isEmpty {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(roundedRect: selection, xRadius: 13, yRadius: 13).fill()
            NSGraphicsContext.restoreGraphicsState()
            AsterGlyphRenderer.signal.setStroke()
            let border = NSBezierPath(roundedRect: selection.insetBy(dx: -2, dy: -2), xRadius: 15, yRadius: 15)
            border.lineWidth = 4
            border.stroke()
        }

        let title = "Select exactly what Aster✱ should teach"
        let subtitle = "Drag around an equation, diagram, paragraph, chart, code block, or problem  ·  Click for a cursor-centered region  ·  Esc to cancel"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.72)
        ]
        let titleSize = (title as NSString).size(withAttributes: titleAttributes)
        let subtitleSize = (subtitle as NSString).size(withAttributes: subtitleAttributes)
        (title as NSString).draw(
            at: NSPoint(x: (bounds.width - titleSize.width) / 2, y: 42),
            withAttributes: titleAttributes
        )
        (subtitle as NSString).draw(
            at: NSPoint(x: (bounds.width - subtitleSize.width) / 2, y: 75),
            withAttributes: subtitleAttributes
        )
    }
}
