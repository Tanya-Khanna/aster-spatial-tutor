import AppKit

enum AsterGlyphRenderer {
    static let signal = NSColor(calibratedRed: 0.937, green: 0.357, blue: 0.208, alpha: 1)

    static func draw(in rect: NSRect, color: NSColor, alpha: CGFloat = 1) {
        let scale = min(rect.width, rect.height) / 32
        let x = rect.minX + (rect.width - 32 * scale) / 2
        let y = rect.minY + (rect.height - 32 * scale) / 2

        color.withAlphaComponent(alpha).setStroke()
        color.withAlphaComponent(alpha).setFill()

        let cursor = NSBezierPath()
        cursor.move(to: NSPoint(x: x + 3 * scale, y: y + 29 * scale))
        cursor.line(to: NSPoint(x: x + 6.2 * scale, y: y + 16.8 * scale))
        cursor.line(to: NSPoint(x: x + 9 * scale, y: y + 20.1 * scale))
        cursor.line(to: NSPoint(x: x + 14.2 * scale, y: y + 14.9 * scale))
        cursor.line(to: NSPoint(x: x + 16.7 * scale, y: y + 17.4 * scale))
        cursor.line(to: NSPoint(x: x + 11.5 * scale, y: y + 22.6 * scale))
        cursor.line(to: NSPoint(x: x + 15.2 * scale, y: y + 25.7 * scale))
        cursor.close()
        cursor.fill()

        let rays = NSBezierPath()
        rays.lineWidth = 3.2 * scale
        rays.lineCapStyle = .round
        rays.move(to: NSPoint(x: x + 23 * scale, y: y + 19 * scale))
        rays.line(to: NSPoint(x: x + 29 * scale, y: y + 25 * scale))
        rays.move(to: NSPoint(x: x + 23 * scale, y: y + 9 * scale))
        rays.line(to: NSPoint(x: x + 29 * scale, y: y + 4 * scale))
        rays.move(to: NSPoint(x: x + 18 * scale, y: y + 8 * scale))
        rays.line(to: NSPoint(x: x + 18 * scale, y: y + 2 * scale))
        rays.move(to: NSPoint(x: x + 13 * scale, y: y + 13 * scale))
        rays.line(to: NSPoint(x: x + 3 * scale, y: y + 13 * scale))
        rays.stroke()

        NSBezierPath(ovalIn: NSRect(x: x + 15.2 * scale, y: y + 10.2 * scale, width: 5.6 * scale, height: 5.6 * scale)).fill()
    }

    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            draw(in: rect.insetBy(dx: 1, dy: 1), color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Aster star"
        return image
    }
}
