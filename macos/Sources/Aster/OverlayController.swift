import AppKit

@MainActor
final class OverlayController {
    private var panel: NSPanel?
    private let canvas = AnnotationCanvas(frame: .zero)
    private var revealTimer: Timer?

    func show(_ annotations: [ScreenAnnotation], on frame: CGRect) {
        clear()
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        canvas.frame = NSRect(origin: .zero, size: frame.size)
        canvas.annotations = []
        panel.contentView = canvas
        panel.orderFrontRegardless()
        self.panel = panel

        var index = 0
        revealTimer = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            guard index < annotations.count else { timer.invalidate(); return }
            self.canvas.annotations.append(annotations[index])
            self.canvas.needsDisplay = true
            index += 1
        }
    }

    func clear() {
        revealTimer?.invalidate()
        revealTimer = nil
        panel?.orderOut(nil)
        panel = nil
        canvas.annotations = []
    }
}

final class AnnotationCanvas: NSView {
    var annotations: [ScreenAnnotation] = []

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for annotation in annotations { draw(annotation) }
    }

    private func draw(_ annotation: ScreenAnnotation) {
        let color = NSColor.aster(annotation.color)
        let rect = NSRect(
            x: annotation.x * bounds.width,
            y: annotation.y * bounds.height,
            width: max(annotation.width * bounds.width, 18),
            height: max(annotation.height * bounds.height, 18)
        )

        switch annotation.type {
        case "highlight":
            color.withAlphaComponent(0.2).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: -5, dy: -4), xRadius: 8, yRadius: 8).fill()
            color.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 2
            path.move(to: NSPoint(x: rect.minX, y: rect.maxY + 4))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY + 4))
            path.stroke()
        case "circle":
            color.withAlphaComponent(0.13).setFill()
            color.setStroke()
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: -7, dy: -7))
            path.lineWidth = 3.5
            path.fill()
            path.stroke()
        case "arrow":
            let start = NSPoint(x: annotation.x * bounds.width, y: annotation.y * bounds.height)
            let end = NSPoint(x: annotation.endX * bounds.width, y: annotation.endY * bounds.height)
            drawArrow(from: start, to: end, color: color)
        default:
            drawLabel(annotation.text, at: rect.origin, color: color)
        }

        if !annotation.text.isEmpty && annotation.type != "label" {
            let anchor = NSPoint(x: min(rect.maxX + 10, bounds.width - 220), y: max(rect.minY - 4, 16))
            drawLabel(annotation.text, at: anchor, color: color)
        }
    }

    private func drawArrow(from start: NSPoint, to end: NSPoint, color: NSColor) {
        color.setStroke()
        color.setFill()
        let path = NSBezierPath()
        path.lineWidth = 3.5
        path.lineCapStyle = .round
        path.move(to: start)
        path.line(to: end)
        path.stroke()
        let angle = atan2(end.y - start.y, end.x - start.x)
        let size: CGFloat = 13
        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: NSPoint(x: end.x - size * cos(angle - .pi / 6), y: end.y - size * sin(angle - .pi / 6)))
        head.line(to: NSPoint(x: end.x - size * cos(angle + .pi / 6), y: end.y - size * sin(angle + .pi / 6)))
        head.close()
        head.fill()
    }

    private func drawLabel(_ text: String, at point: NSPoint, color: NSColor) {
        guard !text.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = NSRect(x: point.x, y: point.y, width: min(size.width + 20, 220), height: size.height + 12)
        NSColor.windowBackgroundColor.withAlphaComponent(0.94).setFill()
        color.setStroke()
        let bubble = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        bubble.lineWidth = 1.5
        bubble.fill()
        bubble.stroke()
        (text as NSString).draw(at: NSPoint(x: rect.minX + 10, y: rect.minY + 6), withAttributes: attributes)
    }
}

extension NSColor {
    static func aster(_ name: String) -> NSColor {
        switch name {
        case "mint": return NSColor(calibratedRed: 0.22, green: 0.78, blue: 0.57, alpha: 1)
        case "coral": return NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.38, alpha: 1)
        case "blue": return NSColor(calibratedRed: 0.18, green: 0.55, blue: 1.0, alpha: 1)
        default: return NSColor(calibratedRed: 0.47, green: 0.31, blue: 0.98, alpha: 1)
        }
    }
}
