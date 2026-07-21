import CoreGraphics
import Darwin
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

@Test func tutorBarExposesFourIntuitiveContextModes() {
    #expect(ContextMode.allCases.map(\.label) == ["Whole Screen", "Point", "Region", "Freehand Loop"])
    #expect(ContextMode.allCases.first == .wholeScreen)
    #expect(ContextMode.point.guidance.contains("Click once"))
}

@MainActor
@Test func pointModeLocksTheExplicitClickInsteadOfFollowingTheCursor() {
    let (region, pointer) = ContextSelectionController.pointTarget(
        at: NSPoint(x: 1_520, y: 640),
        within: NSSize(width: 1_920, height: 1_080)
    )
    #expect(region.rect.contains(CGPoint(x: 1_520.0 / 1_920.0, y: 640.0 / 1_080.0)))
    #expect(abs(pointer.x - 0.5) < 0.001)
    #expect(abs(pointer.y - 0.5) < 0.001)
}

@MainActor
@Test func tutorPanelFloatsWithoutActivatingTheApplication() {
    #expect(TutorPanelConfiguration.styleMask.contains(.nonactivatingPanel))
    #expect(TutorPanelConfiguration.collectionBehavior.contains(.canJoinAllSpaces))
    #expect(TutorPanelConfiguration.collectionBehavior.contains(.fullScreenAuxiliary))

    let panel = AsterKeyPanel(
        contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
        styleMask: TutorPanelConfiguration.styleMask,
        backing: .buffered,
        defer: false
    )
    #expect(panel.canBecomeKey)
    #expect(!panel.canBecomeMain)
    panel.close()
}

@Test func freehandLoopAndStablePointerRoundTrip() throws {
    let target = CaptureTarget(
        kind: .displayRegion,
        displayID: 7,
        region: ContextRegion(x: 0.2, y: 0.25, width: 0.4, height: 0.35),
        windowID: nil,
        appName: "Safari",
        windowTitle: ContextMode.freehandLoop.label,
        anchor: nil,
        selectionPath: [
            NormalizedPoint(x: 0.05, y: 0.4),
            NormalizedPoint(x: 0.45, y: 0.05),
            NormalizedPoint(x: 0.95, y: 0.55),
            NormalizedPoint(x: 0.35, y: 0.95)
        ],
        pointer: NormalizedPoint(x: 0.4, y: 0.5)
    )
    let decoded = try JSONDecoder().decode(CaptureTarget.self, from: JSONEncoder().encode(target))
    #expect(decoded == target)
    #expect(decoded.selectionPath?.count == 4)
    #expect(decoded.pointer == NormalizedPoint(x: 0.4, y: 0.5))
}

@MainActor
@Test func wakePhraseRequiresExplicitAsterInvocation() {
    #expect(VoiceServices.containsWakePhrase("Hey Aster, explain this") == true)
    #expect(VoiceServices.containsWakePhrase("Hey Esther") == true)
    #expect(VoiceServices.questionAfterWakePhrase("Hey Aster, why does this term disappear?") == "why does this term disappear?")
    #expect(VoiceServices.containsWakePhrase("hey, Astor") == true)
    #expect(VoiceServices.containsWakePhrase("Aster is a flower") == false)
    #expect(VoiceServices.containsWakePhrase("explain this") == false)
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

@Test func apiKeyFormatRejectsMissingAndPlaceholderValues() {
    #expect(OpenAIClient.hasPlausibleAPIKeyFormat("") == false)
    #expect(OpenAIClient.hasPlausibleAPIKeyFormat("sk-demo") == false)
    #expect(OpenAIClient.hasPlausibleAPIKeyFormat("not-a-key") == false)
    #expect(OpenAIClient.hasPlausibleAPIKeyFormat("sk-proj-1234567890abcdefghijklmnop") == true)
}

@Test func apiUsageAccumulatesWithoutEstimatingDollarCost() {
    var usage = APIUsage.zero
    usage.add(APIUsage(inputTokens: 120, outputTokens: 30, totalTokens: 150))
    usage.add(APIUsage(inputTokens: 50, outputTokens: 20, totalTokens: 70))
    #expect(usage.inputTokens == 170)
    #expect(usage.outputTokens == 50)
    #expect(usage.totalTokens == 220)
}

@MainActor
@Test func onboardingRestartsOnlyForANewInstalledBundle() {
    #expect(TutorModel.shouldStartOnboarding(
        completed: true,
        hasStoredKey: true,
        previousInstallIdentifier: "device:old-inode",
        currentInstallIdentifier: "device:new-inode"
    ))
    #expect(!TutorModel.shouldStartOnboarding(
        completed: true,
        hasStoredKey: true,
        previousInstallIdentifier: "device:same-inode",
        currentInstallIdentifier: "device:same-inode"
    ))
    #expect(TutorModel.shouldStartOnboarding(
        completed: true,
        hasStoredKey: false,
        previousInstallIdentifier: "device:same-inode",
        currentInstallIdentifier: "device:same-inode"
    ))
}

@Test func settingsExposeFiveStableNativePanes() {
    #expect(SettingsPane.allCases.map(\.rawValue) == ["general", "voice", "permissions", "learning", "account"])
    #expect(SettingsPane.permissions.systemImage == "lock.shield")
    #expect(SettingsPane.account.title == "Account")
}

@Test func relocationGuardRecognizesStableAndTemporaryLocations() {
    let installed = AppRelocationService.status(
        for: URL(fileURLWithPath: "/Applications/Aster.app", isDirectory: true),
        quarantineOverride: false
    )
    #expect(installed.isInApplications)
    #expect(!installed.requiresRelocation)

    let downloaded = AppRelocationService.status(
        for: URL(fileURLWithPath: "/Users/test/Downloads/Aster.app", isDirectory: true),
        quarantineOverride: true
    )
    #expect(downloaded.isQuarantined)
    #expect(downloaded.requiresRelocation)

    let translocated = AppRelocationService.status(
        for: URL(fileURLWithPath: "/private/var/folders/xy/AppTranslocation/ABC123/d/Aster.app", isDirectory: true),
        quarantineOverride: false
    )
    #expect(translocated.isTranslocated)
    #expect(translocated.requiresRelocation)
}

@Test func relocationInstallCopiesBundleAndClearsQuarantine() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("Downloads/Aster.app", isDirectory: true)
    let applications = root.appendingPathComponent("Applications", isDirectory: true)
    let executable = source.appendingPathComponent("Contents/MacOS/Aster")
    defer { try? fileManager.removeItem(at: root) }

    try fileManager.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
    try fileManager.createDirectory(at: applications, withIntermediateDirectories: true)
    try Data("aster".utf8).write(to: executable)
    source.withUnsafeFileSystemRepresentation { path in
        guard let path else { return }
        "0081;test".withCString { value in
            _ = setxattr(path, "com.apple.quarantine", value, strlen(value), 0, 0)
        }
    }

    let installed = try AppRelocationService.installInApplications(from: source, applicationsDirectory: applications)
    #expect(installed == applications.appendingPathComponent("Aster.app", isDirectory: true))
    #expect(fileManager.fileExists(atPath: installed.appendingPathComponent("Contents/MacOS/Aster").path))
    let quarantineSize = installed.withUnsafeFileSystemRepresentation { path in
        guard let path else { return -1 }
        return getxattr(path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW)
    }
    #expect(quarantineSize < 0)
}
