import CoreGraphics
import Foundation
import Testing
@testable import Aster

@Test func contextRegionClampsToDisplay() {
    let region = ContextRegion(x: -0.2, y: 0.9, width: 1.4, height: 0.5)
    #expect(region.x == 0)
    #expect(region.y == 0.9)
    #expect(region.width == 1)
    #expect(abs(region.height - 0.1) < 0.0001)
}

@Test func selectedContextMapsBackToExactScreenCoordinates() {
    let region = ContextRegion(x: 0.25, y: 0.20, width: 0.50, height: 0.40)
    let annotation = ScreenAnnotation(
        id: "target", type: "circle",
        x: 0.20, y: 0.25, width: 0.30, height: 0.20,
        endX: 0.50, endY: 0.45, text: "term", color: "violet"
    )
    let mapped = AnnotationGeometry.normalizedRect(for: annotation, within: region)
    #expect(abs(mapped.minX - 0.35) < 0.0001)
    #expect(abs(mapped.minY - 0.30) < 0.0001)
    #expect(abs(mapped.width - 0.15) < 0.0001)
    #expect(abs(mapped.height - 0.08) < 0.0001)
}

@Test func retinaCropUsesNormalizedTopLeftCoordinates() {
    let region = ContextRegion(x: 0.10, y: 0.25, width: 0.40, height: 0.50)
    let rect = ScreenCaptureService.pixelRect(for: region, imageWidth: 3000, imageHeight: 2000)
    #expect(rect == CGRect(x: 300, y: 500, width: 1200, height: 1000))
}

@Test func coordinateAccuracyBenchmarkCoversDenseTargets() {
    // 400 deterministic placements across narrow equations, diagrams, and charts.
    // The mapping must remain exact in normalized space before display rounding.
    for index in 0..<400 {
        let fx = Double((index * 37) % 80) / 100
        let fy = Double((index * 53) % 80) / 100
        let region = ContextRegion(x: fx * 0.4, y: fy * 0.35, width: 0.42, height: 0.38)
        let ax = Double((index * 17) % 90) / 100
        let ay = Double((index * 29) % 90) / 100
        let annotation = ScreenAnnotation(
            id: "b\(index)", type: "circle", x: ax, y: ay, width: 0.05, height: 0.04,
            endX: ax, endY: ay, text: "", color: "violet"
        )
        let mapped = AnnotationGeometry.normalizedRect(for: annotation, within: region)
        #expect(abs(mapped.minX - (region.x + ax * region.width)) < 0.000_000_1)
        #expect(abs(mapped.minY - (region.y + ay * region.height)) < 0.000_000_1)
    }
}

@Test func displayAndWindowTargetsRoundTrip() throws {
    let target = CaptureTarget(
        kind: .window, displayID: 42,
        region: ContextRegion(x: 0.1, y: 0.2, width: 0.6, height: 0.5),
        windowID: 99, appName: "Safari", windowTitle: "Lesson",
        anchor: SemanticAnchor(
            label: "√dₖ", bounds: ContextRegion(x: 0.4, y: 0.3, width: 0.1, height: 0.1),
            confidence: 0.93, fingerprint: "abc", lastResolvedAt: Date(timeIntervalSince1970: 1)
        )
    )
    let decoded = try JSONDecoder().decode(CaptureTarget.self, from: JSONEncoder().encode(target))
    #expect(decoded == target)
}

@Test func learnerMemoryPersistsMasteryAndMisconceptions() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("profile.json")
    let store = LearnerMemoryStore(fileURL: url)
    let assessment = AssessmentResult(
        correct: false,
        score: 0.4,
        feedback: "The direction is right, but the reason is missing.",
        demonstrated: ["softmax purpose"],
        shakyAreas: ["square-root scaling"],
        nextStrategy: "Compare variance at two dimensions."
    )
    let updated = store.update(
        profile: .empty,
        conceptID: "attention-scaling",
        title: "Attention scaling",
        assessment: assessment
    )
    let reloaded = store.load()
    #expect(updated.totalChecks == 1)
    #expect(reloaded.memory(for: "attention-scaling")?.understood == ["softmax purpose"])
    #expect(reloaded.memory(for: "attention-scaling")?.shakyAreas == ["square-root scaling"])
    #expect(reloaded.memory(for: "attention-scaling")?.nextStrategy == "Compare variance at two dimensions.")
    #expect(reloaded.memory(for: "attention-scaling")?.dependencies.contains("softmax") == true)
    #expect(reloaded.memory(for: "attention-scaling")?.misconceptionCluster == "scale-and-dimensions")
    #expect(reloaded.memory(for: "attention-scaling")?.evidence.count == 1)
    #expect(reloaded.memory(for: "attention-scaling")?.isReviewDue == false)
}

@MainActor
@Test func demoLoopAlwaysDiagnosesBeforeTeachingAndEndsWithTransfer() {
    let diagnostic = TutorModel.demoDiagnostic(for: "Why does x minus h move right?")
    #expect(diagnostic.options.count >= 2)
    let lesson = TutorModel.demoLesson(for: diagnostic, option: diagnostic.options[0])
    #expect(!lesson.steps.isEmpty)
    #expect(lesson.steps.allSatisfy { $0.annotations.count <= 4 })
    #expect(!lesson.check.question.isEmpty)
    #expect(!lesson.check.successCriteria.isEmpty)
    #expect(lesson.toolSuggestion == "desmos")
}
