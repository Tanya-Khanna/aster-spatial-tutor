import AppKit
import Vision

/// Uses local OCR to turn "the thing under my cursor" into a recoverable object.
/// Images never leave the Mac here. Diagram-only selections still retain the
/// cursor-centered visual fingerprint and use region tracking as a fallback.
final class SemanticAnchorTracker {
    private var sequence = VNSequenceRequestHandler()
    private var trackedObject: VNDetectedObjectObservation?

    func anchor(in screen: CapturedScreen) -> SemanticAnchor? {
        let observations = recognize(in: screen.jpegData)
        let focus = localCursor(in: screen) ?? CGPoint(x: 0.5, y: 0.5)
        guard !observations.isEmpty else {
            let rect = CGRect(x: max(focus.x - 0.09, 0), y: max(focus.y - 0.09, 0), width: 0.18, height: 0.18)
            trackedObject = VNDetectedObjectObservation(boundingBox: bottomLeft(rect))
            return SemanticAnchor(label: "visual object under cursor", bounds: ContextRegion(normalized: rect), confidence: 0.5, fingerprint: "visual", lastResolvedAt: Date())
        }
        let best = observations.min { distance($0.boundingBox, focus) < distance($1.boundingBox, focus) }
        guard let best, let text = best.topCandidates(1).first?.string, !text.isEmpty else { return nil }
        let rect = topLeft(best.boundingBox)
        trackedObject = VNDetectedObjectObservation(boundingBox: best.boundingBox)
        return SemanticAnchor(
            label: String(text.prefix(120)),
            bounds: ContextRegion(normalized: rect),
            confidence: Double(best.confidence),
            fingerprint: fingerprint(text),
            lastResolvedAt: Date()
        )
    }

    func recover(_ anchor: SemanticAnchor, in screen: CapturedScreen) -> SemanticAnchor? {
        if anchor.fingerprint == "visual", let tracked = trackVisualObject(in: screen.jpegData) {
            var result = anchor
            result.bounds = ContextRegion(normalized: topLeft(tracked.boundingBox))
            result.confidence = Double(tracked.confidence)
            result.lastResolvedAt = Date()
            return result
        }
        let needle = normalized(anchor.label)
        guard !needle.isEmpty else { return nil }
        let candidates = recognize(in: screen.jpegData).compactMap { observation -> (VNRecognizedTextObservation, String)? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return (observation, text)
        }
        let match = candidates.max { lhs, rhs in
            similarity(normalized(lhs.1), needle) < similarity(normalized(rhs.1), needle)
        }
        guard let match, similarity(normalized(match.1), needle) >= 0.45 else {
            guard let tracked = trackVisualObject(in: screen.jpegData), tracked.confidence >= 0.35 else { return nil }
            var result = anchor
            result.bounds = ContextRegion(normalized: topLeft(tracked.boundingBox))
            result.confidence = Double(tracked.confidence)
            result.lastResolvedAt = Date()
            return result
        }
        var result = anchor
        result.label = String(match.1.prefix(120))
        result.bounds = ContextRegion(normalized: topLeft(match.0.boundingBox))
        result.confidence = Double(match.0.confidence)
        result.lastResolvedAt = Date()
        trackedObject = VNDetectedObjectObservation(boundingBox: match.0.boundingBox)
        return result
    }

    private func trackVisualObject(in jpeg: Data) -> VNDetectedObjectObservation? {
        guard let input = trackedObject,
              let image = NSImage(data: jpeg),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let request = VNTrackObjectRequest(detectedObjectObservation: input)
        request.trackingLevel = .accurate
        do { try sequence.perform([request], on: cgImage, orientation: .up) } catch {
            sequence = VNSequenceRequestHandler()
            return nil
        }
        guard let result = request.results?.first as? VNDetectedObjectObservation else { return nil }
        trackedObject = result
        return result
    }

    private func recognize(in jpeg: Data) -> [VNRecognizedTextObservation] {
        guard let image = NSImage(data: jpeg),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.012
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        do { try handler.perform([request]) } catch { return [] }
        return request.results ?? []
    }

    private func localCursor(in screen: CapturedScreen) -> CGPoint? {
        let target = screen.target
        if target.kind == .window, let windowID = target.windowID,
           let bounds = ScreenCaptureService.windowBounds(windowID: CGWindowID(windowID)) {
            let point = CGEvent(source: nil)?.location ?? .zero
            guard bounds.contains(point) else { return nil }
            return CGPoint(x: (point.x - bounds.minX) / bounds.width, y: (point.y - bounds.minY) / bounds.height)
        }
        let cursor = screen.cursorPosition
        let x = (cursor.x - screen.screenFrame.minX) / screen.screenFrame.width
        let y = (screen.screenFrame.maxY - cursor.y) / screen.screenFrame.height
        guard target.region.rect.contains(CGPoint(x: x, y: y)) else { return nil }
        return CGPoint(x: (x - target.region.x) / target.region.width, y: (y - target.region.y) / target.region.height)
    }

    private func topLeft(_ visionRect: CGRect) -> CGRect {
        CGRect(x: visionRect.minX, y: 1 - visionRect.maxY, width: visionRect.width, height: visionRect.height)
    }

    private func bottomLeft(_ topLeftRect: CGRect) -> CGRect {
        CGRect(x: topLeftRect.minX, y: 1 - topLeftRect.maxY, width: topLeftRect.width, height: topLeftRect.height)
    }

    private func distance(_ rect: CGRect, _ point: CGPoint) -> Double {
        let dx = rect.midX - point.x
        let dy = (1 - rect.midY) - point.y
        return sqrt(dx * dx + dy * dy)
    }

    private func normalized(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func fingerprint(_ text: String) -> String {
        String(normalized(text).unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) ^ UInt64($1.value) }, radix: 16)
    }

    private func similarity(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        if lhs.contains(rhs) || rhs.contains(lhs) { return Double(min(lhs.count, rhs.count)) / Double(max(lhs.count, rhs.count)) }
        let a = Set(lhs), b = Set(rhs)
        return Double(a.intersection(b).count) / Double(max(a.union(b).count, 1))
    }
}
