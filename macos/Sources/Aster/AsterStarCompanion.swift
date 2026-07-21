import AppKit

/// A quiet spatial pin used only after the learner explicitly chooses Point.
/// The Aster✱ mark itself lives in the tutor bar; this overlay never becomes a
/// second floating mascot or an idle screen decoration.
@MainActor
final class AsterStarCompanion {
    private var panel: NSPanel?
    private var pinView: AsterTargetPinView?
    private var timer: Timer?
    private(set) var globalPoint: CGPoint?

    func showPin(at point: CGPoint) {
        hide(rememberPoint: false)
        globalPoint = point
        let size = NSSize(width: 34, height: 34)
        let panel = NSPanel(
            contentRect: NSRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let view = AsterTargetPinView(frame: NSRect(origin: .zero, size: size))
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true
        panel.sharingType = .readOnly
        panel.orderFrontRegardless()
        self.panel = panel
        pinView = view
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak view] _ in
            view?.phase += 0.055
            view?.needsDisplay = true
        }
    }

    func setReading() {
        pinView?.isReading = true
        pinView?.needsDisplay = true
    }

    func hide(rememberPoint: Bool = true) {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
        pinView = nil
        if !rememberPoint { globalPoint = nil }
    }
}

private final class AsterTargetPinView: NSView {
    var phase: Double = 0
    var isReading = false

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        if isReading {
            let pulse = CGFloat((sin(phase * 2.2) + 1) / 2)
            AsterGlyphRenderer.signal.withAlphaComponent(0.10 + 0.10 * (1 - pulse)).setStroke()
            let radius = 9 + pulse * 6
            let halo = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            halo.lineWidth = 2
            halo.stroke()
        }
        AsterGlyphRenderer.signal.withAlphaComponent(0.16).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)).fill()
        AsterGlyphRenderer.signal.setStroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10))
        ring.lineWidth = 2
        ring.stroke()
        AsterGlyphRenderer.signal.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 1.8, y: center.y - 1.8, width: 3.6, height: 3.6)).fill()
    }
}
