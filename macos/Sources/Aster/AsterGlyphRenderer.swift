import AppKit

enum AsterGlyphRenderer {
    static let signal = NSColor(calibratedRed: 0.937, green: 0.357, blue: 0.208, alpha: 1)

    static func draw(in rect: NSRect, color: NSColor, alpha: CGFloat = 1) {
        let scale = min(rect.width, rect.height) / 32
        let x = rect.minX + (rect.width - 32 * scale) / 2
        let y = rect.minY + (rect.height - 32 * scale) / 2

        color.withAlphaComponent(alpha).setStroke()
        color.withAlphaComponent(alpha).setFill()

        let underline = NSBezierPath()
        underline.lineWidth = 3.2 * scale
        underline.lineCapStyle = .round
        underline.move(to: NSPoint(x: x + 5 * scale, y: y + 8 * scale))
        underline.curve(
            to: NSPoint(x: x + 27 * scale, y: y + 12 * scale),
            controlPoint1: NSPoint(x: x + 10 * scale, y: y + 5 * scale),
            controlPoint2: NSPoint(x: x + 20 * scale, y: y + 6.2 * scale)
        )
        underline.stroke()

        let cursorArm = NSBezierPath()
        cursorArm.lineWidth = 3.2 * scale
        cursorArm.lineCapStyle = .round
        cursorArm.lineJoinStyle = .round
        cursorArm.move(to: NSPoint(x: x + 7 * scale, y: y + 11 * scale))
        cursorArm.line(to: NSPoint(x: x + 24 * scale, y: y + 27 * scale))
        cursorArm.move(to: NSPoint(x: x + 24 * scale, y: y + 27 * scale))
        cursorArm.line(to: NSPoint(x: x + 16.5 * scale, y: y + 25.5 * scale))
        cursorArm.move(to: NSPoint(x: x + 24 * scale, y: y + 27 * scale))
        cursorArm.line(to: NSPoint(x: x + 22.5 * scale, y: y + 19.5 * scale))
        cursorArm.stroke()

        let shortArm = NSBezierPath()
        shortArm.lineWidth = 3.2 * scale
        shortArm.lineCapStyle = .round
        shortArm.move(to: NSPoint(x: x + 6 * scale, y: y + 24 * scale))
        shortArm.line(to: NSPoint(x: x + 20 * scale, y: y + 17 * scale))
        shortArm.stroke()

        NSBezierPath(ovalIn: NSRect(x: x + 23.5 * scale, y: y + 4.5 * scale, width: 5 * scale, height: 5 * scale)).fill()
    }

    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            draw(in: rect.insetBy(dx: 1, dy: 1), color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Aster"
        return image
    }
}
