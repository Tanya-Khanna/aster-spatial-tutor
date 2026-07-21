import AppKit

@MainActor
final class AsterStarCompanion {
    enum Mode { case arriving, reading, bookmark }

    private var panel: NSPanel?
    private var starView: AsterStarView?
    private var timer: Timer?
    private(set) var globalPoint: CGPoint?
    var onClick: (() -> Void)?

    func landBesideCursor() {
        show(at: NSEvent.mouseLocation, mode: .arriving)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
            guard self?.panel != nil else { return }
            self?.setReading()
        }
    }

    func setReading() {
        starView?.mode = .reading
        starView?.needsDisplay = true
    }

    func showBookmark(at point: CGPoint) {
        show(at: point, mode: .bookmark)
    }

    func hide(rememberPoint: Bool = true) {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
        starView = nil
        if !rememberPoint { globalPoint = nil }
    }

    private func show(at point: CGPoint, mode: Mode) {
        hide(rememberPoint: false)
        globalPoint = point
        let size = NSSize(width: 46, height: 46)
        let panel = NSPanel(
            contentRect: NSRect(x: point.x + 10, y: point.y - 34, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let view = AsterStarView(frame: NSRect(origin: .zero, size: size))
        view.mode = mode
        view.onClick = { [weak self] in self?.onClick?() }
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = mode != .bookmark
        panel.sharingType = .readOnly
        panel.orderFrontRegardless()
        self.panel = panel
        starView = view
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak view] _ in
            view?.phase += 0.055
            view?.needsDisplay = true
        }
    }
}

private final class AsterStarView: NSView {
    var mode: AsterStarCompanion.Mode = .arriving
    var phase: Double = 0
    var onClick: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard mode == .bookmark else { return }
        onClick?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self))
    }

    override func draw(_ dirtyRect: NSRect) {
        let pulse = mode == .reading ? 1 + 0.10 * sin(phase * 2.4) : 1
        let landing = mode == .arriving ? min(CGFloat(phase * 2.4), 1) : 1
        let scale = CGFloat(pulse) * (0.45 + 0.55 * landing)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)

        if mode == .reading {
            AsterGlyphRenderer.signal.withAlphaComponent(0.12 + 0.08 * CGFloat((sin(phase * 2) + 1) / 2)).setStroke()
            let readingStroke = NSBezierPath()
            readingStroke.lineWidth = 2
            readingStroke.lineCapStyle = .round
            readingStroke.move(to: NSPoint(x: 7, y: 8))
            readingStroke.curve(to: NSPoint(x: 39, y: 13), controlPoint1: NSPoint(x: 16, y: 3), controlPoint2: NSPoint(x: 31, y: 5))
            readingStroke.stroke()
            let glance = NSPoint(x: center.x + CGFloat(cos(phase * 1.7)) * 5, y: center.y + CGFloat(sin(phase * 2.1)) * 3)
            AsterGlyphRenderer.signal.withAlphaComponent(0.28).setFill()
            NSBezierPath(ovalIn: NSRect(x: glance.x - 2, y: glance.y - 2, width: 4, height: 4)).fill()
        }

        let markSize = 30 * scale
        AsterGlyphRenderer.draw(
            in: NSRect(x: center.x - markSize / 2, y: center.y - markSize / 2, width: markSize, height: markSize),
            color: AsterGlyphRenderer.signal
        )

        if mode == .bookmark {
            AsterGlyphRenderer.signal.withAlphaComponent(0.16).setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 9, y: bounds.minY + 4, width: 5, height: 5)).fill()
        }
    }
}
