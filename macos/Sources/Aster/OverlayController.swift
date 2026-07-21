import AppKit

@MainActor
final class OverlayController {
    private var panel: NSPanel?
    private let canvas = AnnotationCanvas(frame: .zero)
    private var revealTimer: Timer?
    private var animationTimer: Timer?
    private let companion = AsterStarCompanion()
    var onBookmarkClick: (() -> Void)? {
        didSet { companion.onClick = onBookmarkClick }
    }

    func arriveBesideCursor() {
        clearAnnotationPanel()
        companion.landBesideCursor()
    }

    func showReadingState() { companion.setReading() }

    func show(_ annotations: [ScreenAnnotation], primitives: [DiagramPrimitive] = [], on frame: CGRect, within region: ContextRegion) {
        let origin = companion.globalPoint ?? NSEvent.mouseLocation
        clearAnnotationPanel()
        companion.hide()
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
        panel.sharingType = .readOnly
        canvas.frame = NSRect(origin: .zero, size: frame.size)
        canvas.annotations = []
        canvas.primitives = primitives
        canvas.contextRegion = region
        canvas.sourcePoint = NSPoint(x: origin.x - frame.minX, y: frame.maxY - origin.y)
        canvas.alphaValue = 1
        panel.contentView = canvas
        panel.orderFrontRegardless()
        self.panel = panel
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.canvas.animationPhase += 0.025
            self.canvas.needsDisplay = true
        }

        var index = 0
        revealTimer = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            guard index < annotations.count else { timer.invalidate(); return }
            self.canvas.annotations.append(annotations[index])
            self.canvas.morphingID = annotations[index].id
            self.canvas.morphStartedAt = self.canvas.animationPhase
            self.canvas.needsDisplay = true
            index += 1
        }
    }

    func fadeScaffolding() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.65
            canvas.animator().alphaValue = 0.22
        }
        companion.showBookmark(at: bookmarkPoint())
    }

    func clear() {
        clearAnnotationPanel()
        companion.hide(rememberPoint: false)
    }

    private func clearAnnotationPanel() {
        revealTimer?.invalidate()
        revealTimer = nil
        animationTimer?.invalidate()
        animationTimer = nil
        panel?.orderOut(nil)
        panel = nil
        canvas.annotations = []
        canvas.primitives = []
    }

    private func bookmarkPoint() -> CGPoint {
        guard let panel else { return companion.globalPoint ?? NSEvent.mouseLocation }
        if let annotation = canvas.annotations.last {
            let point = AnnotationGeometry.normalizedPoint(x: annotation.endX, y: annotation.endY, within: canvas.contextRegion)
            return CGPoint(x: panel.frame.minX + point.x * panel.frame.width, y: panel.frame.maxY - point.y * panel.frame.height)
        }
        return companion.globalPoint ?? NSEvent.mouseLocation
    }
}

final class AnnotationCanvas: NSView {
    var annotations: [ScreenAnnotation] = []
    var primitives: [DiagramPrimitive] = []
    var contextRegion: ContextRegion = .fullScreen
    var animationPhase: Double = 0
    var sourcePoint: NSPoint?
    var morphingID: String?
    var morphStartedAt: Double = 0

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if let sourcePoint, let morphingID,
           let annotation = annotations.first(where: { $0.id == morphingID }) {
            let progress = min(max((animationPhase - morphStartedAt) / 0.34, 0), 1)
            if progress < 1 { drawSourceGlyph(at: sourcePoint, progress: progress, toward: mappedPoint(x: annotation.endX, y: annotation.endY)) }
        }
        for primitive in primitives { draw(primitive) }
        for annotation in annotations { draw(annotation) }
    }

    private func draw(_ primitive: DiagramPrimitive) {
        let color = NSColor.aster(primitive.color)
        let start = mappedPoint(x: primitive.x, y: primitive.y)
        let end = mappedPoint(x: primitive.endX, y: primitive.endY)
        let rect = NSRect(
            x: start.x,
            y: start.y,
            width: max(CGFloat(primitive.width) * CGFloat(contextRegion.width) * bounds.width, 24),
            height: max(CGFloat(primitive.height) * CGFloat(contextRegion.height) * bounds.height, 24)
        )
        switch primitive.type {
        case "line":
            color.setStroke(); let path = NSBezierPath(); path.lineWidth = 3; path.move(to: start); path.line(to: end); path.stroke()
        case "arrow": drawArrow(from: start, to: end, color: color)
        case "node":
            NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill(); color.setStroke()
            let shape = NSBezierPath(ovalIn: rect); shape.lineWidth = 3; shape.fill(); shape.stroke()
            drawCentered(primitive.text, in: rect)
        case "box":
            NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill(); color.setStroke()
            let shape = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12); shape.lineWidth = 3; shape.fill(); shape.stroke()
            drawCentered(primitive.text, in: rect)
        default: drawLabel(primitive.text, at: start, color: color)
        }
    }

    private func draw(_ annotation: ScreenAnnotation) {
        let color = NSColor.aster(annotation.color)
        let progress = annotation.id == morphingID ? min(max((animationPhase - morphStartedAt) / 0.34, 0), 1) : 1
        let finalRect = mappedRect(for: annotation)
        let rect = interpolatedRect(from: sourcePoint ?? finalRect.origin, to: finalRect, progress: progress)

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
            let finalStart = mappedPoint(x: annotation.x, y: annotation.y)
            let finalEnd = mappedPoint(x: annotation.endX, y: annotation.endY)
            let start = interpolatedPoint(from: sourcePoint ?? finalStart, to: finalStart, progress: progress)
            let end = interpolatedPoint(from: sourcePoint ?? finalStart, to: finalEnd, progress: progress)
            drawArrow(from: start, to: end, color: color)
        case "flow":
            let finalStart = mappedPoint(x: annotation.x, y: annotation.y)
            let finalEnd = mappedPoint(x: annotation.endX, y: annotation.endY)
            let start = interpolatedPoint(from: sourcePoint ?? finalStart, to: finalStart, progress: progress)
            let end = interpolatedPoint(from: sourcePoint ?? finalStart, to: finalEnd, progress: progress)
            drawArrow(from: start, to: end, color: color)
            drawFlow(from: start, to: end, color: color)
        case "focus":
            drawFocus(around: rect, color: color)
        case "comparison":
            color.withAlphaComponent(0.16).setFill()
            color.setStroke()
            let shape = NSBezierPath(roundedRect: rect.insetBy(dx: -6, dy: -6), xRadius: 10, yRadius: 10)
            shape.setLineDash([7, 5], count: 2, phase: CGFloat(animationPhase * 12))
            shape.lineWidth = 2.5
            shape.fill()
            shape.stroke()
        case "mask":
            NSColor.windowBackgroundColor.withAlphaComponent(0.84).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9).fill()
        default:
            drawLabel(annotation.text, at: rect.origin, color: color)
        }

        if !annotation.text.isEmpty && annotation.type != "label" {
            let anchor = NSPoint(x: min(rect.maxX + 10, bounds.width - 220), y: max(rect.minY - 4, 16))
            drawLabel(annotation.text, at: anchor, color: color)
        }
    }

    private func mappedPoint(x: Double, y: Double) -> NSPoint {
        let normalized = AnnotationGeometry.normalizedPoint(x: x, y: y, within: contextRegion)
        return NSPoint(x: normalized.x * bounds.width, y: normalized.y * bounds.height)
    }

    private func interpolatedPoint(from: NSPoint, to: NSPoint, progress: Double) -> NSPoint {
        NSPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
    }

    private func interpolatedRect(from: NSPoint, to: NSRect, progress: Double) -> NSRect {
        NSRect(
            x: from.x + (to.minX - from.x) * progress,
            y: from.y + (to.minY - from.y) * progress,
            width: max(to.width * progress, 2),
            height: max(to.height * progress, 2)
        )
    }

    private func drawSourceGlyph(at source: NSPoint, progress: Double, toward target: NSPoint) {
        let point = interpolatedPoint(from: source, to: target, progress: progress * 0.78)
        let size = CGFloat(24 * (1 - progress) + 8)
        AsterGlyphRenderer.draw(
            in: NSRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size),
            color: AsterGlyphRenderer.signal,
            alpha: CGFloat(1 - progress * 0.65)
        )
    }

    private func mappedRect(for annotation: ScreenAnnotation) -> NSRect {
        let normalized = AnnotationGeometry.normalizedRect(for: annotation, within: contextRegion)
        return NSRect(
            x: normalized.minX * bounds.width,
            y: normalized.minY * bounds.height,
            width: max(normalized.width * bounds.width, 18),
            height: max(normalized.height * bounds.height, 18)
        )
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

    private func drawFlow(from start: NSPoint, to end: NSPoint, color: NSColor) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        for index in 0..<4 {
            let progress = (animationPhase + Double(index) * 0.25).truncatingRemainder(dividingBy: 1)
            let center = NSPoint(x: start.x + dx * progress, y: start.y + dy * progress)
            color.withAlphaComponent(0.9).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)).fill()
        }
    }

    private func drawFocus(around rect: NSRect, color: NSColor) {
        NSColor.black.withAlphaComponent(0.48).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: max(rect.minY, 0)).fill()
        NSRect(x: 0, y: rect.maxY, width: bounds.width, height: max(bounds.height - rect.maxY, 0)).fill()
        NSRect(x: 0, y: rect.minY, width: max(rect.minX, 0), height: rect.height).fill()
        NSRect(x: rect.maxX, y: rect.minY, width: max(bounds.width - rect.maxX, 0), height: rect.height).fill()
        color.setStroke()
        let ring = NSBezierPath(roundedRect: rect.insetBy(dx: -8, dy: -8), xRadius: 12, yRadius: 12)
        ring.lineWidth = 3
        ring.stroke()
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

    private func drawCentered(_ text: String, in rect: NSRect) {
        guard !text.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
            withAttributes: attributes
        )
    }
}

extension NSColor {
    static func aster(_ name: String) -> NSColor {
        switch name {
        case "signal": return AsterGlyphRenderer.signal
        case "mint": return NSColor(calibratedRed: 0.22, green: 0.78, blue: 0.57, alpha: 1)
        case "coral": return NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.38, alpha: 1)
        case "blue": return NSColor(calibratedRed: 0.18, green: 0.55, blue: 1.0, alpha: 1)
        default: return AsterGlyphRenderer.signal
        }
    }
}
