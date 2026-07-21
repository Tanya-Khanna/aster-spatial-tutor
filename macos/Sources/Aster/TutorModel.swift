import AppKit
import AVFoundation
import Foundation
import Speech
import SwiftUI

@MainActor
final class TutorModel: ObservableObject {
    static let shared = TutorModel()

    @Published var phase: TutorPhase = .ready
    @Published var query = ""
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .aster, text: "Ask about the whole screen, point to one thing, or narrow the view with a region or freehand loop. I’ll diagnose first, then teach it where it lives.", kind: .message)
    ]
    @Published private(set) var apiKey: String
    @Published var apiKeyDraft = ""
    @Published private(set) var apiKeyStatus: APIKeyStatus
    @Published var onboardingStep: OnboardingStep
    @Published var precisionMode = UserDefaults.standard.bool(forKey: "precisionMode") {
        didSet { UserDefaults.standard.set(precisionMode, forKey: "precisionMode") }
    }
    @Published var settingsPane = SettingsPane(rawValue: UserDefaults.standard.string(forKey: "settingsPane") ?? "") ?? .general {
        didSet { UserDefaults.standard.set(settingsPane.rawValue, forKey: "settingsPane") }
    }
    @Published var narrationRate: Float = UserDefaults.standard.object(forKey: "narrationRate") as? Float ?? 0.48 {
        didSet {
            UserDefaults.standard.set(narrationRate, forKey: "narrationRate")
            learnerProfile.preferences.narrationRate = Double(narrationRate)
            memoryStore.save(learnerProfile)
        }
    }
    @Published var isListening = false
    @Published var conversationMode = UserDefaults.standard.object(forKey: "conversationMode") as? Bool ?? true {
        didSet { UserDefaults.standard.set(conversationMode, forKey: "conversationMode") }
    }
    @Published var listenOnOpen = UserDefaults.standard.object(forKey: "listenOnOpen") as? Bool ?? true {
        didSet { UserDefaults.standard.set(listenOnOpen, forKey: "listenOnOpen") }
    }
    @Published var autoSendVoice = UserDefaults.standard.object(forKey: "autoSendVoice") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoSendVoice, forKey: "autoSendVoice") }
    }
    @Published var wakePhraseEnabled = UserDefaults.standard.bool(forKey: "wakePhraseEnabled") {
        didSet {
            UserDefaults.standard.set(wakePhraseEnabled, forKey: "wakePhraseEnabled")
            wakePhraseEnabled ? voice.startWakeListening() : voice.stopWakeListening()
        }
    }
    @Published private(set) var wakeListeningState: WakeListeningState = .off
    @Published var isFollowing = false
    @Published var isVideoMode = false
    @Published var contextMode: ContextMode = .wholeScreen
    @Published var contextRegion: ContextRegion?
    @Published var contextTarget: CaptureTarget?
    @Published var anchorStatus = "Cursor-local context"
    @Published var diagnostic: DiagnosticPlan?
    @Published var lastLesson: LessonPlan?
    @Published var lessonStepIndex = 0
    @Published var learnerProfile: LearnerProfile
    @Published var lastAssessment: AssessmentResult?
    @Published var isPanelVisible = false
    @Published var isPanelExpanded = false
    @Published var actionPermission: ActionPermission = ActionPermission(rawValue: UserDefaults.standard.string(forKey: "actionPermission") ?? "") ?? .askEveryTime {
        didSet { UserDefaults.standard.set(actionPermission.rawValue, forKey: "actionPermission") }
    }
    @Published var actionHistory: [TutorActionRecord] = []
    @Published private(set) var screenPermission: PermissionState = .notDetermined
    @Published private(set) var microphonePermission: PermissionState = .notDetermined
    @Published private(set) var speechPermission: PermissionState = .notDetermined
    @Published private(set) var relocationStatus: AppRelocationStatus
    @Published private(set) var isRelocatingApplication = false
    @Published private(set) var relocationErrorMessage: String?
    @Published private(set) var screenPermissionRecoveryMessage: String?
    @Published private(set) var sessionUsage: APIUsage = .zero
    @Published private(set) var sessionRequestCount = 0

    var onShowPanel: (() -> Void)?
    var onHidePanel: (() -> Void)?
    var onPanelExpansionChanged: ((Bool) -> Void)?
    var onShowWelcome: (() -> Void)?
    var onShowSettings: ((SettingsPane) -> Void)?

    private let capture = ScreenCaptureService()
    private let client = OpenAIClient()
    private lazy var voice = VoiceServices()
    private let memoryStore = LearnerMemoryStore()
    private let anchorTracker = SemanticAnchorTracker()
    private let browserVideo = BrowserVideoService()
    private let contextSelector = ContextSelectionController()
    private let tools = ToolActionService()
    private(set) var overlay = OverlayController()
    private var capturedContext: CapturedScreen?
    private var recentFrames: [CapturedScreen] = []
    private var followTimer: Timer?
    private var pendingQuestion = ""
    private var selectedDiagnosis: DiagnosticOption?
    private var shownStepIDs = Set<String>()
    private var phaseBeforeListening: TutorPhase = .ready
    private var lessonAnchor: SemanticAnchor?
    private var resumeVideoAfterCheck = false
    private var lastExternalPointer = NSEvent.mouseLocation
    private var sourceApplicationName = ""
    private var consecutiveFrameChanges = 0

    private init() {
        let initialRelocationStatus = AppRelocationService.status()
        relocationStatus = initialRelocationStatus
        // Relocation is a true pre-onboarding gate. Do not touch Keychain from a
        // temporary/translocated process because that can prompt before the guard.
        let storedKey = initialRelocationStatus.requiresRelocation
            ? ""
            : KeychainStore.load().trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = storedKey
        apiKeyStatus = storedKey.isEmpty ? .unauthenticated : .authenticated(hint: Self.keyHint(storedKey))
        let completed = UserDefaults.standard.bool(forKey: "onboardingComplete")
        let currentInstallIdentifier = Self.currentInstallIdentifier()
        let previousInstallIdentifier = UserDefaults.standard.string(forKey: "installIdentifier")
        let shouldRestartOnboarding = Self.shouldStartOnboarding(
            completed: completed,
            hasStoredKey: !storedKey.isEmpty,
            previousInstallIdentifier: previousInstallIdentifier,
            currentInstallIdentifier: currentInstallIdentifier
        )
        if previousInstallIdentifier != currentInstallIdentifier {
            UserDefaults.standard.set(false, forKey: "onboardingComplete")
        }
        UserDefaults.standard.set(currentInstallIdentifier, forKey: "installIdentifier")
        onboardingStep = shouldRestartOnboarding ? .introduction : .ready
        learnerProfile = memoryStore.load()
        if !initialRelocationStatus.requiresRelocation {
            voice.onText = { [weak self] text in self?.query = text }
            voice.onFinalText = { [weak self] text in
                guard let self else { return }
                self.isListening = false
                self.phase = self.phaseBeforeListening
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return }
                self.query = cleaned
                if self.autoSendVoice { self.submit() }
            }
            voice.onFinished = { [weak self] in self?.voiceDidFinish() }
            voice.onWakeWord = { [weak self] in self?.activateFromWakePhrase() }
            voice.onWakeStatus = { [weak self] state in self?.wakeListeningState = state }
        }
        tools.onAction = { [weak self] action in
            guard let self else { return }
            self.actionHistory.append(action)
            self.actionHistory = Array(self.actionHistory.suffix(30))
        }
        if !initialRelocationStatus.requiresRelocation {
            refreshPermissionStatuses()
            if wakePhraseEnabled && isOnboardingComplete { voice.startWakeListening() }
        }
    }

    static func shouldStartOnboarding(
        completed: Bool,
        hasStoredKey: Bool,
        previousInstallIdentifier: String?,
        currentInstallIdentifier: String
    ) -> Bool {
        previousInstallIdentifier != currentInstallIdentifier || !completed || !hasStoredKey
    }

    private static func currentInstallIdentifier() -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: Bundle.main.bundlePath)
        let device = (attributes?[.systemNumber] as? NSNumber)?.uint64Value ?? 0
        let inode = (attributes?[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        if device != 0 || inode != 0 { return "\(device):\(inode)" }

        // This fallback keeps launches stable on file systems that do not expose inode metadata.
        return Bundle.main.bundlePath
    }

    var isAuthenticated: Bool { apiKeyStatus.isAuthenticated && !apiKey.isEmpty }

    var isOnboardingComplete: Bool {
        UserDefaults.standard.bool(forKey: "onboardingComplete") && isAuthenticated && onboardingStep == .ready
    }

    var sessionUsageLabel: String {
        sessionUsage.totalTokens.formatted() + " tokens"
    }

    var isRunningFromApplications: Bool {
        relocationStatus.isInApplications && !relocationStatus.isTranslocated
    }

    var requiresApplicationRelocation: Bool {
        relocationStatus.requiresRelocation
    }

    func activate() {
        isPanelVisible = true
        onShowPanel?()
    }

    func activateFromHotKey() {
        guard !requiresApplicationRelocation else {
            onShowWelcome?()
            return
        }
        guard requireAPIKey() else { return }
        openTutorBar(startListening: listenOnOpen)
    }

    private func activateFromWakePhrase() {
        guard !requiresApplicationRelocation else {
            onShowWelcome?()
            return
        }
        guard requireAPIKey() else { return }
        openTutorBar(startListening: false)
        phaseBeforeListening = phase
        isListening = true
        phase = .listening
    }

    private func openTutorBar(startListening: Bool) {
        lastExternalPointer = NSEvent.mouseLocation
        if !isPanelVisible {
            sourceApplicationName = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
            contextMode = .wholeScreen
            isPanelExpanded = false
            onPanelExpansionChanged?(false)
            configureLiveTarget()
        } else if contextMode == .wholeScreen {
            // Refresh a live whole-display scope, but never replace an explicit
            // Point, Region, or Freehand Loop selection when the bar is reopened.
            configureLiveTarget()
        }
        startFollowing()
        activate()
        if startListening { startQuestionListeningIfAvailable() }
    }

    func closePanel() {
        contextSelector.cancel()
        stopFollowing()
        overlay.clear()
        voice.stopSpeaking()
        voice.stopListening(resumeWake: true)
        isListening = false
        contextMode = .wholeScreen
        contextRegion = nil
        contextTarget = nil
        capturedContext = nil
        recentFrames = []
        consecutiveFrameChanges = 0
        diagnostic = nil
        isVideoMode = false
        phase = .ready
        isPanelExpanded = false
        onPanelExpansionChanged?(false)
        isPanelVisible = false
        onHidePanel?()
    }

    func setPanelExpanded(_ expanded: Bool) {
        guard isPanelExpanded != expanded else { return }
        isPanelExpanded = expanded
        onPanelExpansionChanged?(expanded)
    }

    func clearLesson() {
        overlay.clear()
        voice.stopSpeaking()
        diagnostic = nil
        lastAssessment = nil
        phase = isFollowing ? .following : .ready
    }

    func saveAPIKey() {
        let candidate = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard OpenAIClient.hasPlausibleAPIKeyFormat(candidate) else {
            apiKeyStatus = .invalid(message: "Enter a complete OpenAI API key beginning with sk-.")
            return
        }
        apiKeyStatus = .validating
        Task {
            do {
                try await client.validateAPIKey(candidate)
                try KeychainStore.save(candidate)
                apiKey = candidate
                apiKeyDraft = ""
                apiKeyStatus = .authenticated(hint: Self.keyHint(candidate))
                messages.append(ChatMessage(role: .aster, text: "OpenAI connected. Your key is stored only in macOS Keychain and can be removed from Settings.", kind: .memory))
                if onboardingStep == .apiKey { onboardingStep = .ready }
            } catch {
                apiKeyStatus = .invalid(message: error.localizedDescription)
            }
        }
    }

    func removeAPIKey() {
        do {
            try KeychainStore.delete()
            apiKey = ""
            apiKeyDraft = ""
            apiKeyStatus = .unauthenticated
            UserDefaults.standard.set(false, forKey: "onboardingComplete")
            onboardingStep = .apiKey
            voice.stopWakeListening()
            clearLesson()
            messages = [ChatMessage(role: .aster, text: "You’re signed out. Add an OpenAI API key to start a new teaching turn.", kind: .message)]
            onShowWelcome?()
        } catch {
            apiKeyStatus = .invalid(message: error.localizedDescription)
        }
    }

    func advanceOnboarding() {
        switch onboardingStep {
        case .introduction: onboardingStep = .permissions
        case .permissions: onboardingStep = .apiKey
        case .apiKey where isAuthenticated: onboardingStep = .ready
        case .apiKey: break
        case .ready: finishOnboarding()
        }
    }

    func moveOnboardingBack() {
        guard let previous = OnboardingStep(rawValue: max(0, onboardingStep.rawValue - 1)) else { return }
        onboardingStep = previous
    }

    func finishOnboarding() {
        guard isAuthenticated else {
            onboardingStep = .apiKey
            return
        }
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        onboardingStep = .ready
        if wakePhraseEnabled { voice.startWakeListening() }
    }

    func showSettings(_ pane: SettingsPane? = nil) {
        guard !requiresApplicationRelocation else {
            onShowWelcome?()
            return
        }
        if let pane { settingsPane = pane }
        onShowSettings?(settingsPane)
    }

    func resetLearnerMemory() {
        memoryStore.reset()
        learnerProfile = .empty
        lastAssessment = nil
        messages.append(ChatMessage(role: .aster, text: "Learner memory reset. Future lessons will begin without prior mastery evidence.", kind: .memory))
    }

    func refreshPermissionStatuses() {
        if CGPreflightScreenCaptureAccess() {
            screenPermission = .granted
            screenPermissionRecoveryMessage = nil
        } else {
            screenPermission = UserDefaults.standard.bool(forKey: "screenPermissionRequested") ? .denied : .notDetermined
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: microphonePermission = .granted
        case .notDetermined: microphonePermission = .notDetermined
        default: microphonePermission = .denied
        }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: speechPermission = .granted
        case .notDetermined: speechPermission = .notDetermined
        default: speechPermission = .denied
        }
    }

    func requestScreenPermission() {
        UserDefaults.standard.set(true, forKey: "screenPermissionRequested")
        if CGRequestScreenCaptureAccess() {
            screenPermission = .granted
            screenPermissionRecoveryMessage = nil
        } else {
            screenPermission = .denied
            screenPermissionRecoveryMessage = "macOS has not attached Screen & System Audio Recording access to this copy of Aster✱ yet."
        }
    }

    func checkScreenPermissionAfterGrant() {
        UserDefaults.standard.set(true, forKey: "screenPermissionRequested")
        if CGPreflightScreenCaptureAccess() {
            screenPermission = .granted
            screenPermissionRecoveryMessage = nil
        } else {
            screenPermission = .denied
            screenPermissionRecoveryMessage = "Aster✱ still cannot see Screen & System Audio Recording access. Remove every old Aster entry in Privacy & Security → Screen & System Audio Recording, add /Applications/Aster.app again, turn it on, then restart Aster✱."
        }
    }

    func requestVoicePermissions() {
        voice.requestPermissions { [weak self] in self?.refreshPermissionStatuses() }
    }

    func openScreenPermissionSettings() {
        openSystemSettings(anchor: "Privacy_ScreenCapture")
    }

    func revealRunningApplication() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    func revealApplicationsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
    }

    func moveToApplicationsAndRelaunch() {
        guard !isRelocatingApplication else { return }
        isRelocatingApplication = true
        relocationErrorMessage = nil
        let sourceURL = relocationStatus.bundleURL

        Task {
            do {
                let destinationURL = try await Task.detached(priority: .userInitiated) {
                    try AppRelocationService.installInApplications(from: sourceURL)
                }.value
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                configuration.createsNewApplicationInstance = true
                NSWorkspace.shared.openApplication(at: destinationURL, configuration: configuration) { _, error in
                    Task { @MainActor in
                        if let error {
                            self.isRelocatingApplication = false
                            self.relocationErrorMessage = "Aster✱ was copied to Applications, but macOS could not relaunch it: \(error.localizedDescription) Open /Applications/Aster.app manually."
                            return
                        }
                        NSApp.terminate(nil)
                    }
                }
            } catch {
                isRelocatingApplication = false
                relocationErrorMessage = "Aster✱ could not move itself: \(error.localizedDescription) Drag Aster.app to Applications manually, then reopen it."
            }
        }
    }

    func restartApplication() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            guard error == nil else {
                self.report(error ?? CaptureError.captureFailed)
                return
            }
            NSApp.terminate(nil)
        }
    }

    func openVoicePermissionSettings() {
        openSystemSettings(anchor: speechPermission == .denied ? "Privacy_SpeechRecognition" : "Privacy_Microphone")
    }

    func openAPIKeyPage() {
        NSWorkspace.shared.open(URL(string: "https://platform.openai.com/api-keys")!)
    }

    func openUsageDashboard() {
        NSWorkspace.shared.open(URL(string: "https://platform.openai.com/usage")!)
    }

    func openBudgetSettings() {
        NSWorkspace.shared.open(URL(string: "https://platform.openai.com/settings/organization/limits")!)
    }

    func recoverFromError() {
        phase = isFollowing ? .following : .ready
    }

    func updateExternalPointer(_ point: NSPoint) {
        lastExternalPointer = point
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            sourceApplicationName = frontmost.localizedName ?? sourceApplicationName
        }
    }

    func setContextMode(_ mode: ContextMode) {
        guard isPanelVisible else { return }
        voice.stopSpeaking()
        if isListening {
            voice.stopListening(resumeWake: false)
            isListening = false
        }
        overlay.clear()
        contextSelector.cancel()
        stopFollowing()
        contextMode = mode
        contextTarget = nil
        contextRegion = nil
        capturedContext = nil
        recentFrames = []
        consecutiveFrameChanges = 0
        diagnostic = nil
        lastAssessment = nil

        switch mode {
        case .wholeScreen:
            configureLiveTarget()
            startFollowing()
            startQuestionListeningIfAvailable()
        case .point, .region, .freehandLoop:
            phase = .selectingContext
            switch mode {
            case .point: anchorStatus = "Click the exact thing you mean · local only"
            case .region: anchorStatus = "Draw one box · local only"
            case .freehandLoop: anchorStatus = "Draw one freehand loop · local only"
            case .wholeScreen: break
            }
            contextSelector.begin(mode: mode) { [weak self] selectedTarget in
                guard let self else { return }
                guard var selectedTarget else {
                    self.contextMode = .wholeScreen
                    self.configureLiveTarget()
                    self.startFollowing()
                    self.activate()
                    self.startQuestionListeningIfAvailable()
                    return
                }
                selectedTarget.appName = self.sourceApplicationName
                selectedTarget.windowTitle = mode.label
                self.lockLocalTarget(selectedTarget)
                self.activate()
            }
        }
    }

    /// Kept as the Region shortcut for menu and legacy call sites.
    func selectContext() {
        setContextMode(.region)
    }

    private func configureLiveTarget() {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(lastExternalPointer) }) ?? NSScreen.main,
              let displayID = ScreenCaptureService.displayID(for: screen) else { return }
        let normalizedX = min(max((lastExternalPointer.x - screen.frame.minX) / screen.frame.width, 0), 1)
        let normalizedY = min(max((screen.frame.maxY - lastExternalPointer.y) / screen.frame.height, 0), 1)
        let region = ContextRegion.fullScreen
        let pointer = NormalizedPoint(
            x: (normalizedX - region.x) / region.width,
            y: (normalizedY - region.y) / region.height
        )
        contextTarget = CaptureTarget(
            kind: .displayRegion,
            displayID: displayID,
            region: region,
            windowID: nil,
            appName: sourceApplicationName,
            windowTitle: contextMode.label,
            anchor: contextTarget?.anchor,
            pointer: pointer
        )
        contextRegion = region
        anchorStatus = "Watching this display locally · nothing sent"
    }

    private func globalPoint(for target: CaptureTarget) -> CGPoint? {
        guard let pointer = target.pointer,
              let screen = ScreenCaptureService.screen(for: CGDirectDisplayID(target.displayID)) else { return nil }
        let normalizedX = target.region.x + pointer.x * target.region.width
        let normalizedY = target.region.y + pointer.y * target.region.height
        return CGPoint(
            x: screen.frame.minX + normalizedX * screen.frame.width,
            y: screen.frame.maxY - normalizedY * screen.frame.height
        )
    }

    private func lockLocalTarget(_ target: CaptureTarget) {
        contextTarget = target
        contextRegion = target.region
        do {
            capturedContext = try capture.capture(target: target)
            recentFrames = capturedContext.map { [$0] } ?? []
            switch contextMode {
            case .point:
                anchorStatus = "Point pinned · move your cursor freely"
                if let globalPoint = globalPoint(for: target) { overlay.pinTarget(at: globalPoint) }
            case .region: anchorStatus = "Region locked · only this box will be sent"
            case .freehandLoop: anchorStatus = "Freehand loop locked · outside content removed locally"
            case .wholeScreen: anchorStatus = "Watching this display locally · nothing sent"
            }
            startFollowing()
            messages.append(ChatMessage(
                role: .aster,
                text: "\(contextMode.label) context locked locally. Nothing is sent until you ask.",
                kind: .memory
            ))
            startQuestionListeningIfAvailable()
        } catch {
            report(error)
        }
    }

    func selectCurrentWindow() {
        voice.stopSpeaking()
        overlay.clear()
        guard let target = contextSelector.selectWindowUnderCursor() else {
            report(CaptureError.captureFailed)
            return
        }
        contextTarget = target
        contextRegion = target.region
        do {
            capturedContext = try capture.capture(target: target)
            if let screen = capturedContext, let anchor = anchorTracker.anchor(in: screen) {
                var anchoredTarget = target
                anchoredTarget.anchor = anchor
                contextTarget = anchoredTarget
                anchorStatus = "Following “\(anchor.label)” in \(target.appName)"
            }
            recentFrames = capturedContext.map { [$0] } ?? []
            if contextTarget?.anchor == nil { anchorStatus = "Following \(target.appName) · \(target.windowTitle)" }
            startFollowing()
            messages.append(ChatMessage(role: .aster, text: "Window locked. I’ll recover its position when it moves or resizes.", kind: .memory))
            activate()
        } catch { report(error) }
    }

    func toggleVideoMode() {
        isVideoMode.toggle()
        if isFollowing { startFollowing() }
        messages.append(ChatMessage(
            role: .aster,
            text: isVideoMode ? "Video context on. I’ll retain four changing local frames and send them only when you ask." : "Video context off. I’ll use the current frame.",
            kind: .memory
        ))
    }

    func toggleFollowing() {
        if isFollowing { stopFollowing() }
        else if contextRegion == nil { selectContext() }
        else { startFollowing() }
    }

    private func startFollowing() {
        guard contextRegion != nil else { return }
        followTimer?.invalidate()
        isFollowing = true
        phase = .following
        followTimer = Timer.scheduledTimer(withTimeInterval: isVideoMode ? 0.75 : 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshContextSilently() }
        }
    }

    private func stopFollowing() {
        followTimer?.invalidate()
        followTimer = nil
        isFollowing = false
        if phase == .following { phase = .ready }
    }

    private func refreshContextSilently() {
        if contextMode == .wholeScreen {
            configureLiveTarget()
        }
        guard let target = contextTarget else { return }
        let detectedVideo = browserVideo.snapshot(appName: target.appName)
        let wasVideoMode = isVideoMode
        if detectedVideo != nil { isVideoMode = true }
        let video = isVideoMode ? detectedVideo : nil
        if let updated = try? capture.capture(target: target, videoContext: video) {
            capturedContext = updated
            contextRegion = updated.contextRegion
            var recoveredTarget = updated.target
            if contextMode == .point, recoveredTarget.anchor == nil,
               let anchor = anchorTracker.anchor(in: updated) {
                recoveredTarget.anchor = anchor
                anchorStatus = "Pointing at “\(anchor.label)” · local confidence \(Int(anchor.confidence * 100))%"
            } else if let anchor = target.anchor {
                if let recovered = anchorTracker.recover(anchor, in: updated) {
                    recoveredTarget.anchor = recovered
                    anchorStatus = "Tracking “\(recovered.label)” · recovered after movement"
                } else {
                    recoveredTarget.anchor = anchor
                    anchorStatus = "Anchor temporarily hidden · keeping last position"
                }
            }
            if contextMode == .point, let resolved = recoveredTarget.anchor {
                recoveredTarget.pointer = NormalizedPoint(
                    x: resolved.bounds.rect.midX,
                    y: resolved.bounds.rect.midY
                )
            }
            contextTarget = recoveredTarget
            if contextMode == .point, let globalPoint = globalPoint(for: recoveredTarget) {
                switch phase {
                case .ready, .following, .listening: overlay.pinTarget(at: globalPoint)
                default: break
                }
            }
            if let previous = recentFrames.last {
                if previous.jpegData != updated.jpegData {
                    consecutiveFrameChanges += 1
                } else {
                    consecutiveFrameChanges = 0
                }
            }
            if consecutiveFrameChanges >= 2 { isVideoMode = true }
            if recentFrames.last?.jpegData != updated.jpegData {
                recentFrames.append(updated)
                recentFrames = Array(recentFrames.suffix(4))
            } else if recentFrames.isEmpty {
                recentFrames = [updated]
            }
            if !wasVideoMode, isVideoMode { startFollowing() }
        }
    }

    func toggleListening() {
        if isListening {
            voice.stopListening(resumeWake: false)
            isListening = false
            phase = phaseBeforeListening
        } else {
            startQuestionListeningIfAvailable(force: true)
        }
    }

    private func startQuestionListeningIfAvailable(force: Bool = false) {
        guard !isListening else { return }
        guard force || listenOnOpen else { return }
        guard force || (microphonePermission == .granted && speechPermission == .granted) else { return }
        voice.stopSpeaking()
        phaseBeforeListening = phase
        isListening = true
        phase = .listening
        voice.startListening()
    }

    func testWakePhrase() {
        if wakePhraseEnabled { voice.startWakeListening() }
        else { wakePhraseEnabled = true }
    }

    func submit() {
        let answer = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        guard requireAPIKey() else { return }
        let wasAwaitingUnderstanding = phase == .awaitingUnderstanding || (isListening && phaseBeforeListening == .awaitingUnderstanding)
        if isListening { toggleListening() }
        query = ""
        setPanelExpanded(true)

        if wasAwaitingUnderstanding, let lesson = lastLesson {
            messages.append(ChatMessage(role: .learner, text: answer, kind: .message))
            Task { await assess(answer: answer, lesson: lesson) }
        } else {
            messages.append(ChatMessage(role: .learner, text: answer, kind: .message))
            Task { await beginDiagnosis(for: answer) }
        }
    }

    func chooseDiagnostic(_ option: DiagnosticOption) {
        guard let diagnostic, let screen = capturedContext else { return }
        selectedDiagnosis = option
        messages.append(ChatMessage(role: .learner, text: option.label, kind: .diagnostic))
        self.diagnostic = nil
        phase = .thinking
        Task { await buildLesson(diagnostic: diagnostic, option: option, screen: screen) }
    }

    func replayCurrentStep() {
        guard let lesson = lastLesson, lesson.steps.indices.contains(lessonStepIndex), let screen = capturedContext else { return }
        let step = lesson.steps[lessonStepIndex]
        overlay.show(anchoredAnnotations(step.annotations), primitives: anchoredPrimitives(step.diagramPrimitives), on: screen.screenFrame, within: screen.contextRegion)
        phase = .teaching
        voice.speak(step.narration)
    }

    func previousStep() {
        guard lessonStepIndex > 0 else { return }
        lessonStepIndex -= 1
        replayCurrentStep()
    }

    func nextStep() {
        voice.stopSpeaking()
        advanceLessonStep()
    }

    func requestReteach(_ style: String) {
        guard let lesson = lastLesson else { return }
        if style.contains("analogy") { learnerProfile.preferences.analogyStyle = "concrete analogy" }
        if style.contains("simply") {
            learnerProfile.preferences.explanationMode = "explain more simply"
            learnerProfile.preferences.difficulty = max(0.15, learnerProfile.preferences.difficulty - 0.1)
        }
        memoryStore.save(learnerProfile)
        overlay.clear()
        phase = isFollowing ? .following : .ready
        let request = "Teach \(lesson.conceptTitle) again \(style), focusing on \(lastAssessment?.shakyAreas.joined(separator: ", ") ?? lesson.diagnosis)."
        messages.append(ChatMessage(role: .learner, text: request, kind: .message))
        Task { await beginDiagnosis(for: request) }
    }

    func askFollowUpInstead() {
        overlay.clear()
        phase = isFollowing ? .following : .ready
        query = "I have a follow-up: "
    }

    func tryTransferProblem() {
        guard let lesson = lastLesson else { return }
        overlay.clear()
        phase = isFollowing ? .following : .ready
        let request = "Give me a nearby transfer problem for \(lesson.conceptTitle). Diagnose what I should practice, then make me predict before teaching."
        messages.append(ChatMessage(role: .learner, text: request, kind: .message))
        Task { await beginDiagnosis(for: request) }
    }

    func increaseDifficulty() {
        learnerProfile.preferences.difficulty = min(0.95, learnerProfile.preferences.difficulty + 0.1)
        learnerProfile.preferences.explanationMode = "more challenging transfer"
        memoryStore.save(learnerProfile)
        practiceShakyAreas()
    }

    func runSuggestedTool() {
        guard let lesson = lastLesson, lesson.toolSuggestion != "none" else { return }
        guard actionPermission != .never else {
            messages.append(ChatMessage(role: .aster, text: "Agent actions are disabled. Change permission to Ask every time or Internal only.", kind: .tool))
            return
        }
        let alert = NSAlert()
        alert.messageText = lesson.toolSuggestion == "desmos" ? "Open a Desmos teaching sandbox?" : "Render a safe Manim template?"
        alert.informativeText = lesson.toolSuggestion == "desmos"
            ? "Aster✱ will open an internal graph sandbox and add the previewed expressions. It will not edit your homework or submit anything."
            : "Aster✱ will run one fixed local template with a  low-resolution preview. It never executes model-authored Python."
        alert.addButton(withTitle: "Demonstrate")
        alert.addButton(withTitle: "Not now")
        NSApp.activate(ignoringOtherApps: true)
        if actionPermission == .askEveryTime, alert.runModal() != .alertFirstButtonReturn { return }

        if lesson.toolSuggestion == "desmos" {
            tools.openDesmos(payload: lesson.toolPayload)
            messages.append(ChatMessage(role: .aster, text: "Opened the two expressions in a learner-controlled Desmos sandbox.", kind: .tool))
        } else {
            phase = .runningTool
            tools.renderManim(payload: lesson.toolPayload) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let movie):
                    self.tools.showManimPreview(
                        movie: movie,
                        template: lesson.toolPayload.manimTemplate,
                        caption: lesson.toolPayload.conceptCaption
                    ) { [weak self] cue in self?.voice.speak(cue, rate: self?.narrationRate ?? 0.48) }
                    self.messages.append(ChatMessage(role: .aster, text: "Rendered the safe \(lesson.toolPayload.manimTemplate) animation locally.", kind: .tool))
                    self.phase = .ready
                case .failure(let error): self.report(error)
                }
            }
        }
    }

    func createScratchWork() {
        let source = lastLesson?.steps.map(\.notebook).joined(separator: "\n\n") ?? "Use this space to reason, sketch a prediction, or write a practice attempt."
        tools.openScratchpad(text: source)
    }

    func previewTyping() {
        guard let payload = lastLesson?.toolPayload else { return }
        tools.previewTyping(payload.primaryExpression, targetApp: contextTarget?.appName ?? "another app")
    }

    func openZoomableContext() {
        guard let image = capturedContext?.jpegData else { return }
        tools.openZoomableContext(jpeg: image)
    }

    func undoLastAction() { tools.undoLast() }

    func practiceShakyAreas() {
        let due = learnerProfile.dueReviews.first ?? learnerProfile.concepts.sorted { $0.mastery < $1.mastery }.first
        let concept = due?.title ?? lastLesson?.conceptTitle ?? "the selected concept"
        let shaky = due?.shakyAreas.joined(separator: ", ") ?? lastAssessment?.shakyAreas.joined(separator: ", ") ?? "the central mechanism"
        let request = "Generate one fresh, ungraded practice problem for \(concept), targeting \(shaky). Make me predict first and adapt the difficulty to my history."
        messages.append(ChatMessage(role: .learner, text: request, kind: .message))
        Task { await beginDiagnosis(for: request) }
    }

    private func beginDiagnosis(for question: String) async {
        guard requireAPIKey() else { return }
        if contextMode == .wholeScreen {
            configureLiveTarget()
        }
        pendingQuestion = question
        lastAssessment = nil
        phase = .seeing
        overlay.showReadingState()
        do {
            let appName = contextTarget?.appName ?? sourceApplicationName
            if let state = browserVideo.snapshot(appName: appName) {
                isVideoMode = true
                if !state.isPaused {
                    resumeVideoAfterCheck = browserVideo.pause(appName: appName)
                    if resumeVideoAfterCheck {
                        messages.append(ChatMessage(role: .aster, text: "Paused at \(Self.timestamp(state.currentTime)) so we can inspect this teaching moment.", kind: .tool))
                    }
                }
            }
            let screen: CapturedScreen
            if let target = contextTarget {
                screen = try capture.capture(target: target, videoContext: isVideoMode ? browserVideo.snapshot(appName: target.appName) : nil)
            } else if let region = contextRegion {
                let target = CaptureTarget.displayRegion(displayID: CGMainDisplayID(), region: region)
                contextTarget = target
                screen = try capture.capture(target: target)
            } else {
                throw CaptureError.captureFailed
            }
            capturedContext = screen
            if let anchor = anchorTracker.anchor(in: screen) {
                var anchoredTarget = screen.target
                anchoredTarget.anchor = anchor
                contextTarget = anchoredTarget
                anchorStatus = "\(contextMode.label) · “\(anchor.label)” · local confidence \(Int(anchor.confidence * 100))%"
            }
            if isVideoMode {
                recentFrames.append(screen)
                recentFrames = Array(recentFrames.suffix(4))
            } else {
                recentFrames = [screen]
            }
            phase = .diagnosing
            let result = try await client.diagnose(
                apiKey: apiKey,
                question: question,
                screen: screen,
                recentFrames: requestFrames(endingWith: screen),
                recentContext: recentContext,
                learnerMemory: learnerProfile.promptSummary,
                safetyIdentifier: safetyIdentifier
            )
            record(result.usage)
            diagnostic = result.value
            if !result.value.priorConnection.isEmpty {
                messages.append(ChatMessage(role: .aster, text: result.value.priorConnection, kind: .memory))
            }
            messages.append(ChatMessage(role: .aster, text: result.value.question, kind: .diagnostic))
            phase = .clarifying
        } catch { report(error) }
    }

    private func buildLesson(diagnostic: DiagnosticPlan, option: DiagnosticOption, screen: CapturedScreen) async {
        guard requireAPIKey() else { return }
        do {
            let result = try await client.makeLesson(
                apiKey: apiKey,
                originalQuestion: pendingQuestion,
                selectedDiagnosis: option,
                diagnostic: diagnostic,
                screen: screen,
                recentFrames: requestFrames(endingWith: screen),
                recentContext: recentContext,
                learnerMemory: learnerProfile.promptSummary,
                precisionMode: precisionMode,
                safetyIdentifier: safetyIdentifier
            )
            record(result.usage)
            present(result.value)
        } catch { report(error) }
    }

    private func present(_ lesson: LessonPlan) {
        lastLesson = lesson
        lessonAnchor = contextTarget?.anchor
        shownStepIDs = []
        lessonStepIndex = 0
        messages.append(ChatMessage(role: .aster, text: "Diagnosis: \(lesson.diagnosis)", kind: .diagnostic))
        showCurrentStep()
    }

    private func showCurrentStep() {
        guard let lesson = lastLesson,
              lesson.steps.indices.contains(lessonStepIndex),
              let screen = capturedContext else { return }
        let step = lesson.steps[lessonStepIndex]
        phase = .teaching
        overlay.show(anchoredAnnotations(step.annotations), primitives: anchoredPrimitives(step.diagramPrimitives), on: screen.screenFrame, within: screen.contextRegion)
        if !shownStepIDs.contains(step.id) {
            messages.append(ChatMessage(role: .aster, text: step.notebook, kind: .insight))
            shownStepIDs.insert(step.id)
        }
        voice.speak(step.narration, rate: narrationRate)
    }

    private func voiceDidFinish() {
        guard phase == .teaching else { return }
        advanceLessonStep()
    }

    private func anchoredAnnotations(_ annotations: [ScreenAnnotation]) -> [ScreenAnnotation] {
        guard let original = lessonAnchor, let current = contextTarget?.anchor else {
            return annotations.map(\.clamped)
        }
        let dx = current.bounds.rect.midX - original.bounds.rect.midX
        let dy = current.bounds.rect.midY - original.bounds.rect.midY
        return annotations.map { item in
            ScreenAnnotation(
                id: item.id,
                type: item.type,
                x: item.x + dx,
                y: item.y + dy,
                width: item.width,
                height: item.height,
                endX: item.endX + dx,
                endY: item.endY + dy,
                text: item.text,
                color: item.color
            ).clamped
        }
    }

    private func anchoredPrimitives(_ primitives: [DiagramPrimitive]) -> [DiagramPrimitive] {
        guard let original = lessonAnchor, let current = contextTarget?.anchor else { return primitives }
        let dx = current.bounds.rect.midX - original.bounds.rect.midX
        let dy = current.bounds.rect.midY - original.bounds.rect.midY
        return primitives.map {
            DiagramPrimitive(
                id: $0.id, type: $0.type,
                x: min(max($0.x + dx, 0), 1), y: min(max($0.y + dy, 0), 1),
                width: $0.width, height: $0.height,
                endX: min(max($0.endX + dx, 0), 1), endY: min(max($0.endY + dy, 0), 1),
                text: $0.text, color: $0.color
            )
        }
    }

    private func advanceLessonStep() {
        guard let lesson = lastLesson else { return }
        if lessonStepIndex + 1 < lesson.steps.count {
            lessonStepIndex += 1
            showCurrentStep()
        } else {
            overlay.fadeScaffolding()
            messages.append(ChatMessage(role: .aster, text: lesson.check.question, kind: .check))
            phase = .awaitingUnderstanding
            if conversationMode && !isListening { toggleListening() }
        }
    }

    private func assess(answer: String, lesson: LessonPlan) async {
        guard requireAPIKey() else { return }
        phase = .assessing
        do {
            let result = try await client.assess(
                apiKey: apiKey,
                lesson: lesson,
                learnerAnswer: answer,
                learnerMemory: learnerProfile.promptSummary,
                safetyIdentifier: safetyIdentifier
            )
            record(result.usage)
            lastAssessment = result.value
            learnerProfile = memoryStore.update(
                profile: learnerProfile,
                conceptID: lesson.conceptID,
                title: lesson.conceptTitle,
                assessment: result.value
            )
            messages.append(ChatMessage(role: .aster, text: result.value.feedback, kind: .assessment))
            if let concept = learnerProfile.memory(for: lesson.conceptID) {
                let shaky = concept.shakyAreas.isEmpty ? "no unresolved misconception recorded" : "still shaky: \(concept.shakyAreas.joined(separator: ", "))"
                messages.append(ChatMessage(
                    role: .aster,
                    text: "Memory updated · \(concept.title) \(Int(concept.mastery * 100))% · \(shaky). Next: \(concept.nextStrategy)",
                    kind: .memory
                ))
            }
            overlay.clear()
            phase = isFollowing ? .following : .ready
            if resumeVideoAfterCheck {
                _ = browserVideo.resume(appName: contextTarget?.appName ?? "")
                resumeVideoAfterCheck = false
                messages.append(ChatMessage(role: .aster, text: "Understanding checked · resumed the video.", kind: .tool))
            }
        } catch { report(error) }
    }

    private func report(_ error: Error) {
        if resumeVideoAfterCheck {
            _ = browserVideo.resume(appName: contextTarget?.appName ?? "")
            resumeVideoAfterCheck = false
        }
        if let apiError = error as? TutorAPIError, case .authentication = apiError {
            apiKeyStatus = .invalid(message: error.localizedDescription)
        }
        phase = .error(error.localizedDescription)
        messages.append(ChatMessage(role: .aster, text: error.localizedDescription, kind: .message))
    }

    private var recentContext: String {
        messages.suffix(8).map { message in
            "\(message.role == .learner ? "Learner" : "Tutor"): \(message.text)"
        }.joined(separator: "\n")
    }

    @discardableResult
    private func requireAPIKey() -> Bool {
        guard isAuthenticated else {
            let message = "Connect your OpenAI API key before starting a teaching turn. Open Aster✱ to add or validate a key."
            phase = .error(message)
            if messages.last?.text != message {
                messages.append(ChatMessage(role: .aster, text: message, kind: .message))
            }
            onboardingStep = .apiKey
            onShowWelcome?()
            return false
        }
        return true
    }

    private func record(_ usage: APIUsage) {
        sessionUsage.add(usage)
        sessionRequestCount += 1
    }

    private func openSystemSettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func requestFrames(endingWith screen: CapturedScreen) -> [CapturedScreen] {
        guard isVideoMode else { return [screen] }
        var frames = recentFrames.filter { $0.capturedAt != screen.capturedAt }
        frames.append(screen)
        return Array(frames.suffix(4))
    }

    private var safetyIdentifier: String {
        let key = "safetyIdentifier"
        if let value = UserDefaults.standard.string(forKey: key) { return value }
        let value = "aster-\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(value, forKey: key)
        return value
    }

    private static func keyHint(_ key: String) -> String {
        "••••••••" + key.suffix(4)
    }

    private static func timestamp(_ seconds: Double) -> String {
        let value = max(Int(seconds.rounded()), 0)
        return String(format: "%d:%02d", value / 60, value % 60)
    }

}
