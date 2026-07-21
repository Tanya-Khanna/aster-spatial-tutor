import AppKit

@MainActor
final class ContextSelectionController {
    private var panel: NSPanel?
    private var completion: ((CaptureTarget?) -> Void)?
    private var activeDisplayID: CGDirectDisplayID?

    static func pointTarget(at point: NSPoint, within size: NSSize) -> (ContextRegion, NormalizedPoint) {
        let width = min(size.width * 0.44, 720)
        let height = min(size.height * 0.42, 480)
        let chosen = NSRect(
            x: min(max(point.x - width / 2, 0), size.width - width),
            y: min(max(point.y - height / 2, 0), size.height - height),
            width: width,
            height: height
        )
        return (
            ContextRegion(
                x: chosen.minX / size.width,
                y: chosen.minY / size.height,
                width: chosen.width / size.width,
                height: chosen.height / size.height
            ),
            NormalizedPoint(
                x: (point.x - chosen.minX) / chosen.width,
                y: (point.y - chosen.minY) / chosen.height
            )
        )
    }

    func begin(mode: ContextMode, completion: @escaping (CaptureTarget?) -> Void) {
        guard mode == .point || mode == .region || mode == .freehandLoop else {
            completion(nil)
            return
        }
        let cursor = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main,
              let displayID = ScreenCaptureService.displayID(for: screen) else { completion(nil); return }
        cancel()
        self.completion = completion
        self.activeDisplayID = displayID

        let panel = AsterKeyPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let view = ContextSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), mode: mode)
        view.onComplete = { [weak self] region, selectionPath, pointer in
            guard let self, let displayID = self.activeDisplayID else { return }
            self.finish(CaptureTarget(
                kind: .displayRegion,
                displayID: displayID,
                region: region,
                windowID: nil,
                appName: "",
                windowTitle: "",
                anchor: nil,
                selectionPath: selectionPath,
                pointer: pointer
            ))
        }
        view.onCancel = { [weak self] in self?.finish(nil) }
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // The selector dims the lesson beneath Aster✱ while leaving the tutor
        // bar visible and interactive one level above it.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.acceptsMouseMovedEvents = true
        panel.sharingType = .readOnly
        panel.setFrame(screen.frame, display: true)
        panel.makeKeyAndOrderFront(nil)
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
    var onComplete: ((ContextRegion, [NormalizedPoint]?, NormalizedPoint?) -> Void)?
    var onCancel: (() -> Void)?
    private let mode: ContextMode
    private var startPoint: NSPoint?
    private var selection = NSRect.zero
    private var freehandPoints: [NSPoint] = []

    init(frame frameRect: NSRect, mode: ContextMode) {
        self.mode = mode
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func mouseMoved(with event: NSEvent) {
        guard mode == .point else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = NSRect(x: point.x - 20, y: point.y - 20, width: 40, height: 40).intersection(bounds)
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        if mode == .point {
            selection = NSRect(x: startPoint!.x - 20, y: startPoint!.y - 20, width: 40, height: 40).intersection(bounds)
        } else {
            selection = NSRect(origin: startPoint!, size: .zero)
        }
        freehandPoints = mode == .freehandLoop ? [startPoint!] : []
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        guard mode != .point else { return }
        let current = convert(event.locationInWindow, from: nil)
        if mode == .freehandLoop,
           freehandPoints.last.map({ hypot($0.x - current.x, $0.y - current.y) >= 3 }) ?? true {
            freehandPoints.append(current)
        }
        if mode == .freehandLoop {
            selection = boundingRect(for: freehandPoints).intersection(bounds)
        } else {
            selection = NSRect(
                x: min(startPoint.x, current.x),
                y: min(startPoint.y, current.y),
                width: abs(current.x - startPoint.x),
                height: abs(current.y - startPoint.y)
            ).intersection(bounds)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let selectedPoint = startPoint else { return }
        if mode == .point {
            let (region, pointer) = ContextSelectionController.pointTarget(at: selectedPoint, within: bounds.size)
            onComplete?(region, nil, pointer)
            return
        }
        if mode == .freehandLoop {
            let current = convert(event.locationInWindow, from: nil)
            freehandPoints.append(current)
            selection = boundingRect(for: freehandPoints).intersection(bounds)
        }
        let chosen = selection.intersection(bounds)
        guard chosen.width >= 18, chosen.height >= 18 else {
            startPoint = nil
            selection = .zero
            freehandPoints = []
            needsDisplay = true
            return
        }
        let region = ContextRegion(
            x: chosen.minX / bounds.width,
            y: chosen.minY / bounds.height,
            width: chosen.width / bounds.width,
            height: chosen.height / bounds.height
        )
        let path: [NormalizedPoint]?
        if mode == .freehandLoop, freehandPoints.count >= 3 {
            path = freehandPoints.map {
                NormalizedPoint(
                    x: ($0.x - chosen.minX) / chosen.width,
                    y: ($0.y - chosen.minY) / chosen.height
                )
            }
        } else {
            path = nil
        }
        onComplete?(region, path, nil)
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
            selectionPath.fill()
            NSGraphicsContext.restoreGraphicsState()
            AsterGlyphRenderer.signal.setStroke()
            let border = selectionPath
            border.lineWidth = 4
            border.stroke()
        }

        let title: String
        let subtitle: String
        switch mode {
        case .point:
            title = "Click the exact thing you mean"
            subtitle = "The pin stays there when you move back to Aster✱  ·  Esc to cancel"
        case .region:
            title = "Box exactly what Aster✱ should see"
            subtitle = "Drag a box around the relevant content  ·  Release to lock it  ·  Esc to cancel"
        case .freehandLoop:
            title = "Loop exactly what Aster✱ should see"
            subtitle = "Draw one freehand loop around the relevant content  ·  Release to lock it  ·  Esc to cancel"
        case .wholeScreen:
            title = ""
            subtitle = ""
        }
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

    private var selectionPath: NSBezierPath {
        if mode == .point { return NSBezierPath(ovalIn: selection) }
        guard mode == .freehandLoop, freehandPoints.count >= 2 else {
            return NSBezierPath(roundedRect: selection.insetBy(dx: -2, dy: -2), xRadius: 15, yRadius: 15)
        }
        let path = NSBezierPath()
        path.move(to: freehandPoints[0])
        freehandPoints.dropFirst().forEach { path.line(to: $0) }
        path.close()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        return path
    }

    private func boundingRect(for points: [NSPoint]) -> NSRect {
        guard let first = points.first else { return .zero }
        let minX = points.reduce(first.x) { min($0, $1.x) }
        let maxX = points.reduce(first.x) { max($0, $1.x) }
        let minY = points.reduce(first.y) { min($0, $1.y) }
        let maxY = points.reduce(first.y) { max($0, $1.y) }
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
