import AppKit
import CoreGraphics

struct CapturedScreen {
    let jpegData: Data
    let screenFrame: CGRect
    let contextRegion: ContextRegion
    let cursorPosition: CGPoint
    let target: CaptureTarget
    let capturedAt: Date
    let videoContext: VideoContext?
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case captureFailed
    case targetMoved
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Allow Screen Recording in System Settings, then reopen Aster✱."
        case .captureFailed: return "Aster✱ could not capture the selected learning context."
        case .targetMoved: return "The selected window closed. Select the learning context again."
        case .encodingFailed: return "Aster✱ could not prepare the selected context."
        }
    }
}

final class ScreenCaptureService {
    func capture(region: ContextRegion = .fullScreen) throws -> CapturedScreen {
        try capture(target: .displayRegion(displayID: CGMainDisplayID(), region: region))
    }

    func capture(target originalTarget: CaptureTarget, videoContext: VideoContext? = nil) throws -> CapturedScreen {
        if !CGPreflightScreenCaptureAccess() {
            guard CGRequestScreenCaptureAccess() else { throw CaptureError.permissionDenied }
        }

        var target = originalTarget
        let displayID = CGDirectDisplayID(target.displayID)
        guard let screen = Self.screen(for: displayID) else { throw CaptureError.captureFailed }

        let sourceImage: CGImage
        let overlayRegion: ContextRegion
        switch target.kind {
        case .displayRegion:
            guard let fullImage = CGDisplayCreateImage(displayID) else { throw CaptureError.captureFailed }
            let pixelRect = Self.pixelRect(for: target.region, imageWidth: fullImage.width, imageHeight: fullImage.height)
            guard let cropped = fullImage.cropping(to: pixelRect) else { throw CaptureError.captureFailed }
            sourceImage = cropped
            overlayRegion = target.region
        case .window:
            guard let windowID = target.windowID,
                  let bounds = Self.windowBounds(windowID: CGWindowID(windowID)),
                  let image = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    CGWindowID(windowID),
                    [.boundsIgnoreFraming, .bestResolution]
                  ) else { throw CaptureError.targetMoved }
            let displayBounds = CGDisplayBounds(displayID)
            overlayRegion = ContextRegion(
                x: (bounds.minX - displayBounds.minX) / displayBounds.width,
                y: (bounds.minY - displayBounds.minY) / displayBounds.height,
                width: bounds.width / displayBounds.width,
                height: bounds.height / displayBounds.height
            )
            target.region = overlayRegion
            sourceImage = image
        }

        let rendered = try render(sourceImage, target: target, screen: screen)
        return CapturedScreen(
            jpegData: rendered,
            screenFrame: screen.frame,
            contextRegion: overlayRegion,
            cursorPosition: NSEvent.mouseLocation,
            target: target,
            capturedAt: Date(),
            videoContext: videoContext
        )
    }

    private func render(_ source: CGImage, target: CaptureTarget, screen: NSScreen) throws -> Data {
        let sourceWidth = CGFloat(source.width)
        let sourceHeight = CGFloat(source.height)
        let targetWidth = min(sourceWidth, 1600)
        let targetHeight = sourceHeight * (targetWidth / sourceWidth)
        let targetSize = NSSize(width: targetWidth, height: targetHeight)
        let image = NSImage(size: targetSize)
        let cursor = NSEvent.mouseLocation

        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: source, size: targetSize).draw(in: NSRect(origin: .zero, size: targetSize))

        let displayBounds = CGDisplayBounds(CGDirectDisplayID(target.displayID))
        let cgCursor = CGPoint(x: cursor.x, y: displayBounds.maxY - cursor.y)
        let local: CGPoint?
        if target.kind == .window {
            if let windowID = target.windowID, let bounds = Self.windowBounds(windowID: CGWindowID(windowID)), bounds.contains(cgCursor) {
                local = CGPoint(x: (cgCursor.x - bounds.minX) / bounds.width, y: (cgCursor.y - bounds.minY) / bounds.height)
            } else { local = nil }
        } else {
            let cursorX = (cursor.x - screen.frame.minX) / screen.frame.width
            let cursorYTop = (screen.frame.maxY - cursor.y) / screen.frame.height
            if target.region.rect.contains(CGPoint(x: cursorX, y: cursorYTop)) {
                local = CGPoint(
                    x: (cursorX - target.region.x) / target.region.width,
                    y: (cursorYTop - target.region.y) / target.region.height
                )
            } else { local = nil }
        }

        if let local {
            let marker = NSPoint(x: local.x * targetWidth, y: targetHeight - (local.y * targetHeight))
            let halo = NSBezierPath(ovalIn: NSRect(x: marker.x - 22, y: marker.y - 22, width: 44, height: 44))
            AsterGlyphRenderer.signal.withAlphaComponent(0.18).setFill()
            halo.fill()
            let ring = NSBezierPath(ovalIn: NSRect(x: marker.x - 8, y: marker.y - 8, width: 16, height: 16))
            AsterGlyphRenderer.signal.setStroke()
            ring.lineWidth = 3
            ring.stroke()
        }
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
            throw CaptureError.encodingFailed
        }
        return jpeg
    }

    static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        }
    }

    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    static func windowBounds(windowID: CGWindowID) -> CGRect? {
        guard let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
              let dictionary = info.first?[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dictionary)
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
