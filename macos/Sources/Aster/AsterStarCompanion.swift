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
        panel.sharingType = .none
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
            NSColor.aster("violet").withAlphaComponent(0.10 + 0.08 * CGFloat((sin(phase * 2) + 1) / 2)).setFill()
            NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3)).fill()
            let glance = NSPoint(x: center.x + CGFloat(cos(phase * 1.7)) * 5, y: center.y + CGFloat(sin(phase * 2.1)) * 3)
            NSColor.aster("violet").withAlphaComponent(0.28).setFill()
            NSBezierPath(ovalIn: NSRect(x: glance.x - 2, y: glance.y - 2, width: 4, height: 4)).fill()
        }

        var transform = AffineTransform()
        transform.translate(x: center.x, y: center.y)
        transform.scale(scale)
        transform.translate(x: -center.x, y: -center.y)
        let path = Self.starPath(center: center, outer: 11, inner: 3.8)
        path.transform(using: transform)
        NSColor.aster("violet").setFill()
        path.fill()

        if mode == .bookmark {
            NSColor.windowBackgroundColor.withAlphaComponent(0.96).setStroke()
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 7, dy: 7))
            ring.lineWidth = 2
            ring.stroke()
        }
    }

    private static func starPath(center: CGPoint, outer: CGFloat, inner: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        for index in 0..<16 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 8
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            index == 0 ? path.move(to: point) : path.line(to: point)
        }
        path.close()
        return path
    }
}
