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
        ChatMessage(role: .aster, text: "Select the exact thing you are learning. I’ll diagnose first, then teach it where it lives.", kind: .message)
    ]
    @Published private(set) var apiKey: String
    @Published var apiKeyDraft = ""
    @Published private(set) var apiKeyStatus: APIKeyStatus
    @Published var onboardingStep: OnboardingStep
    @Published var precisionMode = false
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
    @Published var wakePhraseEnabled = UserDefaults.standard.bool(forKey: "wakePhraseEnabled") {
        didSet {
            UserDefaults.standard.set(wakePhraseEnabled, forKey: "wakePhraseEnabled")
            wakePhraseEnabled ? voice.startWakeListening() : voice.stopWakeListening()
        }
    }
    @Published var isFollowing = false
    @Published var isVideoMode = false
    @Published var contextRegion: ContextRegion?
    @Published var contextTarget: CaptureTarget?
    @Published var anchorStatus = "Cursor-local context"
    @Published var diagnostic: DiagnosticPlan?
    @Published var lastLesson: LessonPlan?
    @Published var lessonStepIndex = 0
    @Published var learnerProfile: LearnerProfile
    @Published var lastAssessment: AssessmentResult?
    @Published var isPanelVisible = false
    @Published var actionPermission: ActionPermission = ActionPermission(rawValue: UserDefaults.standard.string(forKey: "actionPermission") ?? "") ?? .askEveryTime {
        didSet { UserDefaults.standard.set(actionPermission.rawValue, forKey: "actionPermission") }
    }
    @Published var actionHistory: [TutorActionRecord] = []
    @Published private(set) var screenPermission: PermissionState = .notDetermined
    @Published private(set) var microphonePermission: PermissionState = .notDetermined
    @Published private(set) var speechPermission: PermissionState = .notDetermined
    @Published private(set) var sessionUsage: APIUsage = .zero
    @Published private(set) var sessionRequestCount = 0

    var onShowPanel: (() -> Void)?
    var onHidePanel: (() -> Void)?
    var onShowWelcome: (() -> Void)?
    var onShowSettings: (() -> Void)?

    private let capture = ScreenCaptureService()
    private let client = OpenAIClient()
    private let voice = VoiceServices()
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
    private var pendingWakeQuestion = false

    private init() {
        let storedKey = KeychainStore.load().trimmingCharacters(in: .whitespacesAndNewlines)
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
        voice.onText = { [weak self] text in self?.query = text }
        voice.onFinalText = { [weak self] text in
            guard let self else { return }
            self.isListening = false
            self.query = text
            if self.conversationMode { self.submit() }
        }
        voice.onFinished = { [weak self] in self?.voiceDidFinish() }
        voice.onWakeWord = { [weak self] in self?.activateFromWakePhrase() }
        overlay.onBookmarkClick = { [weak self] in self?.reopenBookmarkedLesson() }
        tools.onAction = { [weak self] action in
            guard let self else { return }
            self.actionHistory.append(action)
            self.actionHistory = Array(self.actionHistory.suffix(30))
        }
        refreshPermissionStatuses()
        if wakePhraseEnabled { voice.startWakeListening() }
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

    func activate() {
        isPanelVisible = true
        onShowPanel?()
        NSApp.activate(ignoringOtherApps: true)
    }

    func activateFromHotKey() {
        guard requireAPIKey() else { return }
        if contextRegion == nil {
            selectContext()
            overlay.arriveBesideCursor()
        } else {
            overlay.arriveBesideCursor()
            activate()
        }
    }

    private func activateFromWakePhrase() {
        guard requireAPIKey() else { return }
        pendingWakeQuestion = true
        if contextRegion == nil {
            selectContext()
            overlay.arriveBesideCursor()
        } else {
            overlay.arriveBesideCursor()
            activate()
            if !isListening { toggleListening() }
        }
    }

    private func reopenBookmarkedLesson() {
        activate()
        if lastLesson != nil { replayCurrentStep() }
        else { query = "I have a follow-up: " }
    }

    func closePanel() {
        overlay.clear()
        voice.stopSpeaking()
        isPanelVisible = false
        onHidePanel?()
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
    }

    func showSettings() { onShowSettings?() }

    func resetLearnerMemory() {
        memoryStore.reset()
        learnerProfile = .empty
        lastAssessment = nil
        messages.append(ChatMessage(role: .aster, text: "Learner memory reset. Future lessons will begin without prior mastery evidence.", kind: .memory))
    }

    func refreshPermissionStatuses() {
        if CGPreflightScreenCaptureAccess() {
            screenPermission = .granted
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
        screenPermission = CGRequestScreenCaptureAccess() ? .granted : .denied
    }

    func requestVoicePermissions() {
        voice.requestPermissions { [weak self] in self?.refreshPermissionStatuses() }
    }

    func openScreenPermissionSettings() {
        openSystemSettings(anchor: "Privacy_ScreenCapture")
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

    func selectContext() {
        voice.stopSpeaking()
        overlay.clear()
        onHidePanel?()
        phase = .selectingContext
        contextSelector.begin { [weak self] target in
            guard let self else { return }
            guard let target else {
                self.phase = self.contextRegion == nil ? .ready : .following
                self.activate()
                if self.pendingWakeQuestion {
                    self.pendingWakeQuestion = false
                    if !self.isListening { self.toggleListening() }
                }
                return
            }
            self.contextTarget = target
            self.contextRegion = target.region
            do {
                self.capturedContext = try self.capture.capture(target: target)
                if let screen = self.capturedContext, let anchor = self.anchorTracker.anchor(in: screen) {
                    var anchoredTarget = target
                    anchoredTarget.anchor = anchor
                    self.contextTarget = anchoredTarget
                    self.anchorStatus = "Pointing at “\(anchor.label)” · \(Int(anchor.confidence * 100))% local confidence"
                }
                self.recentFrames = self.capturedContext.map { [$0] } ?? []
                if self.contextTarget?.anchor == nil {
                    self.anchorStatus = "Diagram focus locked at the cursor"
                }
                self.startFollowing()
                self.messages.append(ChatMessage(
                    role: .aster,
                    text: "Context locked. I’ll refresh this region locally and only send it when you ask a question.",
                    kind: .memory
                ))
                self.activate()
            } catch {
                self.report(error)
                self.activate()
            }
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
        followTimer = Timer.scheduledTimer(withTimeInterval: isVideoMode ? 0.75 : 2.0, repeats: true) { [weak self] _ in
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
        guard let target = contextTarget else { return }
        let video = isVideoMode ? browserVideo.snapshot(appName: target.appName) : nil
        if let updated = try? capture.capture(target: target, videoContext: video) {
            capturedContext = updated
            contextRegion = updated.contextRegion
            var recoveredTarget = updated.target
            if let anchor = target.anchor {
                if let recovered = anchorTracker.recover(anchor, in: updated) {
                    recoveredTarget.anchor = recovered
                    anchorStatus = "Tracking “\(recovered.label)” · recovered after movement"
                } else {
                    recoveredTarget.anchor = anchor
                    anchorStatus = "Anchor temporarily hidden · keeping last position"
                }
            }
            contextTarget = recoveredTarget
            if isVideoMode, recentFrames.last?.jpegData != updated.jpegData {
                recentFrames.append(updated)
                recentFrames = Array(recentFrames.suffix(4))
            } else if !isVideoMode {
                recentFrames = [updated]
            }
        }
    }

    func toggleListening() {
        if isListening {
            voice.stopListening()
            isListening = false
            phase = phaseBeforeListening
        } else {
            voice.stopSpeaking() // natural barge-in
            phaseBeforeListening = phase
            isListening = true
            phase = .listening
            voice.startListening()
        }
    }

    func submit() {
        let answer = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        guard requireAPIKey() else { return }
        let wasAwaitingUnderstanding = phase == .awaitingUnderstanding || (isListening && phaseBeforeListening == .awaitingUnderstanding)
        if isListening { toggleListening() }
        query = ""

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
        pendingQuestion = question
        lastAssessment = nil
        phase = .seeing
        overlay.showReadingState()
        do {
            if isVideoMode {
                let appName = contextTarget?.appName ?? ""
                if let state = browserVideo.snapshot(appName: appName), !state.isPaused {
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
