import AppKit
import CoreGraphics

struct CapturedScreen {
    let jpegData: Data
    let screenFrame: CGRect
    let cursorPosition: CGPoint
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case captureFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Allow Screen Recording in System Settings, then reopen Aster."
        case .captureFailed: return "Aster could not capture the selected screen."
        case .encodingFailed: return "Aster could not prepare the screen image."
        }
    }
}

final class ScreenCaptureService {
    func captureMainDisplay() throws -> CapturedScreen {
        if !CGPreflightScreenCaptureAccess() {
            guard CGRequestScreenCaptureAccess() else { throw CaptureError.permissionDenied }
        }

        let displayID = CGMainDisplayID()
        guard let cgImage = CGDisplayCreateImage(displayID),
              let screen = NSScreen.main else {
            throw CaptureError.captureFailed
        }

        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)
        let targetWidth = min(sourceWidth, 1440)
        let targetHeight = sourceHeight * (targetWidth / sourceWidth)
        let targetSize = NSSize(width: targetWidth, height: targetHeight)
        let image = NSImage(size: targetSize)
        let cursor = NSEvent.mouseLocation

        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: cgImage, size: targetSize).draw(in: NSRect(origin: .zero, size: targetSize))

        let normalizedX = (cursor.x - screen.frame.minX) / screen.frame.width
        let normalizedY = (cursor.y - screen.frame.minY) / screen.frame.height
        let marker = NSPoint(x: normalizedX * targetWidth, y: normalizedY * targetHeight)
        let halo = NSBezierPath(ovalIn: NSRect(x: marker.x - 15, y: marker.y - 15, width: 30, height: 30))
        NSColor(calibratedRed: 0.55, green: 0.42, blue: 1.0, alpha: 0.22).setFill()
        halo.fill()
        let dot = NSBezierPath(ovalIn: NSRect(x: marker.x - 4, y: marker.y - 4, width: 8, height: 8))
        NSColor(calibratedRed: 0.45, green: 0.29, blue: 0.98, alpha: 1).setFill()
        dot.fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
            throw CaptureError.encodingFailed
        }
        return CapturedScreen(jpegData: jpeg, screenFrame: screen.frame, cursorPosition: cursor)
    }
}
