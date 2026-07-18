import AppKit
import CoreGraphics

struct CapturedScreen {
    let jpegData: Data
    let screenFrame: CGRect
    let contextRegion: ContextRegion
    let cursorPosition: CGPoint
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case captureFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Allow Screen Recording in System Settings, then reopen Aster."
        case .captureFailed: return "Aster could not capture the selected learning context."
        case .encodingFailed: return "Aster could not prepare the selected context."
        }
    }
}

final class ScreenCaptureService {
    func capture(region: ContextRegion = .fullScreen) throws -> CapturedScreen {
        if !CGPreflightScreenCaptureAccess() {
            guard CGRequestScreenCaptureAccess() else { throw CaptureError.permissionDenied }
        }

        let displayID = CGMainDisplayID()
        guard let fullImage = CGDisplayCreateImage(displayID), let screen = NSScreen.main else {
            throw CaptureError.captureFailed
        }

        let pixelRect = Self.pixelRect(for: region, imageWidth: fullImage.width, imageHeight: fullImage.height)
        guard let cropped = fullImage.cropping(to: pixelRect) else { throw CaptureError.captureFailed }

        let sourceWidth = CGFloat(cropped.width)
        let sourceHeight = CGFloat(cropped.height)
        let targetWidth = min(sourceWidth, 1440)
        let targetHeight = sourceHeight * (targetWidth / sourceWidth)
        let targetSize = NSSize(width: targetWidth, height: targetHeight)
        let image = NSImage(size: targetSize)
        let cursor = NSEvent.mouseLocation

        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: cropped, size: targetSize).draw(in: NSRect(origin: .zero, size: targetSize))

        let cursorX = (cursor.x - screen.frame.minX) / screen.frame.width
        let cursorYTop = (screen.frame.maxY - cursor.y) / screen.frame.height
        if region.rect.contains(CGPoint(x: cursorX, y: cursorYTop)) {
            let localX = (cursorX - region.x) / region.width
            let localYTop = (cursorYTop - region.y) / region.height
            let marker = NSPoint(x: localX * targetWidth, y: targetHeight - (localYTop * targetHeight))
            let halo = NSBezierPath(ovalIn: NSRect(x: marker.x - 18, y: marker.y - 18, width: 36, height: 36))
            NSColor(calibratedRed: 0.55, green: 0.42, blue: 1.0, alpha: 0.22).setFill()
            halo.fill()
            let dot = NSBezierPath(ovalIn: NSRect(x: marker.x - 4, y: marker.y - 4, width: 8, height: 8))
            NSColor(calibratedRed: 0.45, green: 0.29, blue: 0.98, alpha: 1).setFill()
            dot.fill()
        }
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
            throw CaptureError.encodingFailed
        }
        return CapturedScreen(
            jpegData: jpeg,
            screenFrame: screen.frame,
            contextRegion: region,
            cursorPosition: cursor
        )
    }

    static func pixelRect(for region: ContextRegion, imageWidth: Int, imageHeight: Int) -> CGRect {
        let width = CGFloat(imageWidth)
        let height = CGFloat(imageHeight)
        return CGRect(
            x: floor(CGFloat(region.x) * width),
            y: floor(CGFloat(region.y) * height),
            width: max(1, floor(CGFloat(region.width) * width)),
            height: max(1, floor(CGFloat(region.height) * height))
        ).intersection(CGRect(x: 0, y: 0, width: width, height: height))
    }
}
