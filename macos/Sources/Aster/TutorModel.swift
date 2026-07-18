import AppKit
import Foundation
import SwiftUI

@MainActor
final class TutorModel: ObservableObject {
    static let shared = TutorModel()

    @Published var phase: TutorPhase = .ready
    @Published var query = ""
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .aster, text: "Select the exact thing you are learning. I’ll diagnose first, then teach it where it lives.", kind: .message)
    ]
    @Published var apiKey = KeychainStore.load()
    @Published var estimatedSpend = UserDefaults.standard.double(forKey: "estimatedSpend")
    @Published var precisionMode = false
    @Published var narrationRate: Float = 0.48
    @Published var isListening = false
    @Published var isFollowing = false
    @Published var contextRegion: ContextRegion?
    @Published var diagnostic: DiagnosticPlan?
    @Published var lastLesson: LessonPlan?
    @Published var lessonStepIndex = 0
    @Published var learnerProfile: LearnerProfile
    @Published var lastAssessment: AssessmentResult?
    @Published var isPanelVisible = false

    var onShowPanel: (() -> Void)?
    var onHidePanel: (() -> Void)?
    var onShowWelcome: (() -> Void)?

    private let capture = ScreenCaptureService()
    private let client = OpenAIClient()
    private let voice = VoiceServices()
    private let memoryStore = LearnerMemoryStore()
    private let contextSelector = ContextSelectionController()
    private let tools = ToolActionService()
    private(set) var overlay = OverlayController()
    private var capturedContext: CapturedScreen?
    private var followTimer: Timer?
    private var pendingQuestion = ""
    private var selectedDiagnosis: DiagnosticOption?
    private var shownStepIDs = Set<String>()
    private var demoKind: String?
    private var phaseBeforeListening: TutorPhase = .ready

    private init() {
        learnerProfile = memoryStore.load()
        voice.onText = { [weak self] text in self?.query = text }
        voice.onFinished = { [weak self] in self?.voiceDidFinish() }
    }

    func activate() {
        isPanelVisible = true
        onShowPanel?()
        NSApp.activate(ignoringOtherApps: true)
    }

    func activateFromHotKey() {
        if contextRegion == nil {
            selectContext()
        } else {
            activate()
        }
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
        KeychainStore.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func selectContext() {
        voice.stopSpeaking()
        overlay.clear()
        onHidePanel?()
        phase = .selectingContext
        contextSelector.begin { [weak self] region in
            guard let self else { return }
            guard let region else {
                self.phase = self.contextRegion == nil ? .ready : .following
                self.activate()
                return
            }
            self.contextRegion = region
            do {
                self.capturedContext = try self.capture.capture(region: region)
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
        followTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
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
        guard let region = contextRegion else { return }
        if let updated = try? capture.capture(region: region) { capturedContext = updated }
    }

    func toggleListening() {
        if isListening {
            voice.stopListening()
            isListening = false
            phase = phaseBeforeListening
        } else {
            phaseBeforeListening = phase
            isListening = true
            phase = .listening
            voice.startListening()
        }
    }

    func submit() {
        let answer = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
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
        overlay.show(step.annotations.map(\.clamped), on: screen.screenFrame, within: screen.contextRegion)
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

    func runSuggestedTool() {
        guard let lesson = lastLesson, lesson.toolSuggestion != "none" else { return }
        let alert = NSAlert()
        alert.messageText = lesson.toolSuggestion == "desmos" ? "Open a Desmos teaching sandbox?" : "Render a safe Manim template?"
        alert.informativeText = lesson.toolSuggestion == "desmos"
            ? "Aster will open an internal graph sandbox and add the previewed expressions. It will not edit your homework or submit anything."
            : "Aster will run one fixed local template with a  low-resolution preview. It never executes model-authored Python."
        alert.addButton(withTitle: "Demonstrate")
        alert.addButton(withTitle: "Not now")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if lesson.toolSuggestion == "desmos" {
            tools.openDesmos(payload: lesson.toolPayload)
            messages.append(ChatMessage(role: .aster, text: "Opened the two expressions in a learner-controlled Desmos sandbox.", kind: .tool))
        } else {
            phase = .runningTool
            tools.renderManim(payload: lesson.toolPayload) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let movie):
                    NSWorkspace.shared.open(movie)
                    self.messages.append(ChatMessage(role: .aster, text: "Rendered the safe \(lesson.toolPayload.manimTemplate) animation locally.", kind: .tool))
                    self.phase = .ready
                case .failure(let error): self.report(error)
                }
            }
        }
    }

    func runDemo(_ kind: String = "paper") {
        demoKind = kind
        if contextRegion == nil {
            contextRegion = ContextRegion(x: 0.12, y: 0.12, width: 0.70, height: 0.70)
            capturedContext = try? capture.capture(region: contextRegion!)
        }
        activate()
        let question: String
        switch kind {
        case "anatomy": question = "Trace how oxygen crosses this membrane and check if I understand it."
        case "graph": question = "Why does x minus h shift the graph right?"
        default: question = "Why is the equation scaled by the square root of the dimension?"
        }
        messages.append(ChatMessage(role: .learner, text: question, kind: .message))
        Task { await beginDiagnosis(for: question) }
    }

    private func beginDiagnosis(for question: String) async {
        guard checkBudget() else { return }
        pendingQuestion = question
        lastAssessment = nil
        phase = .seeing
        do {
            let screen: CapturedScreen
            if let region = contextRegion {
                screen = try capture.capture(region: region)
            } else {
                throw CaptureError.captureFailed
            }
            capturedContext = screen
            phase = .diagnosing
            let result: TutorResult<DiagnosticPlan>
            if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try await Task.sleep(nanoseconds: 450_000_000)
                result = TutorResult(value: personalizedDemoDiagnostic(for: question), usage: APIUsage(inputTokens: 0, outputTokens: 0), model: "demo")
            } else {
                result = try await client.diagnose(
                    apiKey: apiKey,
                    question: question,
                    screen: screen,
                    recentContext: recentContext,
                    learnerMemory: learnerProfile.promptSummary,
                    safetyIdentifier: safetyIdentifier
                )
            }
            recordUsage(result.usage, model: result.model)
            diagnostic = result.value
            if !result.value.priorConnection.isEmpty {
                messages.append(ChatMessage(role: .aster, text: result.value.priorConnection, kind: .memory))
            }
            messages.append(ChatMessage(role: .aster, text: result.value.question, kind: .diagnostic))
            phase = .clarifying
        } catch { report(error) }
    }

    private func buildLesson(diagnostic: DiagnosticPlan, option: DiagnosticOption, screen: CapturedScreen) async {
        guard checkBudget() else { return }
        do {
            let result: TutorResult<LessonPlan>
            if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try await Task.sleep(nanoseconds: 650_000_000)
                result = TutorResult(value: Self.demoLesson(for: diagnostic, option: option), usage: APIUsage(inputTokens: 0, outputTokens: 0), model: "demo")
            } else {
                result = try await client.makeLesson(
                    apiKey: apiKey,
                    originalQuestion: pendingQuestion,
                    selectedDiagnosis: option,
                    diagnostic: diagnostic,
                    screen: screen,
                    recentContext: recentContext,
                    learnerMemory: learnerProfile.promptSummary,
                    precisionMode: precisionMode,
                    safetyIdentifier: safetyIdentifier
                )
            }
            recordUsage(result.usage, model: result.model)
            present(result.value)
        } catch { report(error) }
    }

    private func present(_ lesson: LessonPlan) {
        lastLesson = lesson
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
        overlay.show(step.annotations.map(\.clamped), on: screen.screenFrame, within: screen.contextRegion)
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

    private func advanceLessonStep() {
        guard let lesson = lastLesson else { return }
        if lessonStepIndex + 1 < lesson.steps.count {
            lessonStepIndex += 1
            showCurrentStep()
        } else {
            overlay.fadeScaffolding()
            messages.append(ChatMessage(role: .aster, text: lesson.check.question, kind: .check))
            phase = .awaitingUnderstanding
        }
    }

    private func assess(answer: String, lesson: LessonPlan) async {
        guard checkBudget() else { return }
        phase = .assessing
        do {
            let result: TutorResult<AssessmentResult>
            if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try await Task.sleep(nanoseconds: 420_000_000)
                let assessment = Self.demoAssessment(answer: answer, lesson: lesson)
                result = TutorResult(value: assessment, usage: APIUsage(inputTokens: 0, outputTokens: 0), model: "demo")
            } else {
                result = try await client.assess(
                    apiKey: apiKey,
                    lesson: lesson,
                    learnerAnswer: answer,
                    learnerMemory: learnerProfile.promptSummary,
                    safetyIdentifier: safetyIdentifier
                )
            }
            recordUsage(result.usage, model: result.model)
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
        } catch { report(error) }
    }

    private func checkBudget() -> Bool {
        guard estimatedSpend < 4.80 else {
            phase = .error("$5 budget guard reached")
            return false
        }
        return true
    }

    private func recordUsage(_ usage: APIUsage, model: String) {
        estimatedSpend += usage.estimatedCost(model: model)
        UserDefaults.standard.set(estimatedSpend, forKey: "estimatedSpend")
    }

    private func report(_ error: Error) {
        phase = .error(error.localizedDescription)
        messages.append(ChatMessage(role: .aster, text: error.localizedDescription, kind: .message))
    }

    private var recentContext: String {
        messages.suffix(8).map { message in
            "\(message.role == .learner ? "Learner" : "Tutor"): \(message.text)"
        }.joined(separator: "\n")
    }

    private var safetyIdentifier: String {
        let key = "safetyIdentifier"
        if let value = UserDefaults.standard.string(forKey: key) { return value }
        let value = "aster-\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(value, forKey: key)
        return value
    }

    private func personalizedDemoDiagnostic(for question: String) -> DiagnosticPlan {
        let base = Self.demoDiagnostic(for: question)
        guard let memory = learnerProfile.memory(for: base.conceptID) else {
            return DiagnosticPlan(
                conceptID: base.conceptID,
                conceptTitle: base.conceptTitle,
                observedObject: base.observedObject,
                question: base.question,
                options: base.options,
                priorConnection: ""
            )
        }
        let understood = memory.understood.isEmpty ? "the foundation" : memory.understood.joined(separator: ", ")
        let shaky = memory.shakyAreas.isEmpty ? "the next transfer step" : memory.shakyAreas.joined(separator: ", ")
        return DiagnosticPlan(
            conceptID: base.conceptID,
            conceptTitle: base.conceptTitle,
            observedObject: base.observedObject,
            question: base.question,
            options: base.options,
            priorConnection: "You previously demonstrated \(understood), while \(shaky) still needs work. Let’s connect them."
        )
    }

    static func demoDiagnostic(for question: String) -> DiagnosticPlan {
        let lower = question.lowercased()
        if lower.contains("oxygen") || lower.contains("membrane") || lower.contains("anatom") {
            return DiagnosticPlan(
                conceptID: "alveolar-diffusion",
                conceptTitle: "Alveolar diffusion",
                observedObject: "the thin membrane between the air space and capillary",
                question: "What feels least clear about this diagram?",
                options: [
                    DiagnosticOption(id: "direction", label: "Why oxygen moves one direction", misconception: "The learner may be treating molecular motion as one-way rather than net diffusion."),
                    DiagnosticOption(id: "thickness", label: "Why the membrane is so thin", misconception: "The learner may not connect diffusion distance to transfer rate."),
                    DiagnosticOption(id: "blood", label: "Where the oxygen enters blood", misconception: "The learner may not be tracking the spatial compartments.")
                ],
                priorConnection: ""
            )
        }
        if lower.contains("shift") || lower.contains("graph") || lower.contains("minus h") {
            return DiagnosticPlan(
                conceptID: "function-horizontal-translation",
                conceptTitle: "Horizontal function translation",
                observedObject: "the x − h term inside the squared expression",
                question: "Which part is causing the sign confusion?",
                options: [
                    DiagnosticOption(id: "inside", label: "Why inside changes run opposite", misconception: "The learner is reading an input transformation like an output movement."),
                    DiagnosticOption(id: "vertex", label: "How x − h locates the vertex", misconception: "The learner has not connected the zero of the inner expression to the vertex."),
                    DiagnosticOption(id: "parameter", label: "What h represents", misconception: "The learner is unsure which quantity h controls.")
                ],
                priorConnection: "You already used parent functions correctly; this time we’ll connect that strength to the input coordinate."
            )
        }
        return DiagnosticPlan(
            conceptID: "attention-scaling",
            conceptTitle: "Scaled dot-product attention",
            observedObject: "the √dₖ denominator in the attention equation",
            question: "What part of the scaling feels mysterious?",
            options: [
                DiagnosticOption(id: "root", label: "Why a square root", misconception: "The learner has not connected dimension to dot-product variance."),
                DiagnosticOption(id: "dimension", label: "What dₖ measures", misconception: "The learner is unsure what space the keys and queries occupy."),
                DiagnosticOption(id: "softmax", label: "Why softmax needs scaling", misconception: "The learner has not connected large logits to softmax saturation.")
            ],
            priorConnection: "You understand what softmax does; scaling is the missing bridge between dot products and softmax confidence."
        )
    }

    static func demoLesson(for diagnostic: DiagnosticPlan, option: DiagnosticOption) -> LessonPlan {
        if diagnostic.conceptID == "function-horizontal-translation" {
            return LessonPlan(
                title: "Make the inside equal zero",
                conceptID: diagnostic.conceptID,
                conceptTitle: diagnostic.conceptTitle,
                diagnosis: option.misconception,
                steps: [
                    LessonStep(id: "g1", narration: "Start inside the parentheses. The square becomes smallest when this entire expression equals zero.", notebook: "Locate a transformed graph by zeroing its inner expression.", annotations: [
                        ScreenAnnotation(id: "g1a", type: "circle", x: 0.35, y: 0.36, width: 0.18, height: 0.10, endX: 0.53, endY: 0.41, text: "set this to 0", color: "violet")
                    ]),
                    LessonStep(id: "g2", narration: "If x minus h equals zero, x must equal h. That is why a positive h places the vertex to the right.", notebook: "x − h = 0  →  x = h. Inside signs describe the input needed, not the direction directly.", annotations: [
                        ScreenAnnotation(id: "g2a", type: "arrow", x: 0.47, y: 0.53, width: 0.12, height: 0.05, endX: 0.66, endY: 0.53, text: "vertex at x = h", color: "coral")
                    ])
                ],
                check: MasteryCheck(question: "Without graphing: where is the vertex of y = (x + 3)²? Explain using the zero of the inside.", successCriteria: "The learner says x = -3 because x + 3 must equal zero.", transferPrompt: "Apply the zero-the-inside method to a new sign."),
                toolSuggestion: "desmos",
                toolPayload: ToolPayload(primaryExpression: "y=(x-h)^2+k", comparisonExpression: "y=x^2", manimTemplate: "none", conceptCaption: "Predict first, then move h and k one at a time.")
            )
        }
        if diagnostic.conceptID == "alveolar-diffusion" {
            return LessonPlan(
                title: "Follow the concentration gradient",
                conceptID: diagnostic.conceptID,
                conceptTitle: diagnostic.conceptTitle,
                diagnosis: option.misconception,
                steps: [
                    LessonStep(id: "a1", narration: "Begin on the side with more oxygen. Molecules move randomly both ways, but more leave the crowded side.", notebook: "Diffusion is random motion with a net flow down a concentration gradient.", annotations: [
                        ScreenAnnotation(id: "a1c", type: "circle", x: 0.24, y: 0.28, width: 0.17, height: 0.20, endX: 0.41, endY: 0.38, text: "higher O₂", color: "blue")
                    ]),
                    LessonStep(id: "a2", narration: "The thin membrane shortens the distance. That lets oxygen reach the capillary faster.", notebook: "Shorter diffusion distance increases transfer rate.", annotations: [
                        ScreenAnnotation(id: "a2h", type: "highlight", x: 0.48, y: 0.22, width: 0.06, height: 0.42, endX: 0.54, endY: 0.43, text: "thin barrier", color: "mint"),
                        ScreenAnnotation(id: "a2a", type: "arrow", x: 0.40, y: 0.42, width: 0.12, height: 0.05, endX: 0.67, endY: 0.42, text: "net O₂ flow", color: "coral")
                    ])
                ],
                check: MasteryCheck(question: "Predict what happens to oxygen transfer if this membrane doubles in thickness—and say why.", successCriteria: "The learner predicts slower transfer because diffusion distance increases.", transferPrompt: "Transfer the distance-rate relationship to a changed membrane."),
                toolSuggestion: "none",
                toolPayload: ToolPayload(primaryExpression: "", comparisonExpression: "", manimTemplate: "none", conceptCaption: "")
            )
        }
        return LessonPlan(
            title: "Keep softmax out of saturation",
            conceptID: diagnostic.conceptID,
            conceptTitle: diagnostic.conceptTitle,
            diagnosis: option.misconception,
            steps: [
                LessonStep(id: "p1", narration: "Each dot product adds contributions from d k dimensions. As that count grows, the typical spread of the dot product grows too.", notebook: "More dimensions make unscaled attention logits spread farther apart.", annotations: [
                    ScreenAnnotation(id: "p1h", type: "highlight", x: 0.28, y: 0.31, width: 0.23, height: 0.09, endX: 0.51, endY: 0.35, text: "dot product grows", color: "mint")
                ]),
                LessonStep(id: "p2", narration: "Dividing by the square root of the dimension restores a stable scale before softmax sees those values.", notebook: "√dₖ normalizes the dot-product standard deviation before softmax.", annotations: [
                    ScreenAnnotation(id: "p2c", type: "circle", x: 0.48, y: 0.35, width: 0.12, height: 0.10, endX: 0.60, endY: 0.40, text: "stabilizes scale", color: "violet"),
                    ScreenAnnotation(id: "p2a", type: "arrow", x: 0.58, y: 0.42, width: 0.10, height: 0.04, endX: 0.73, endY: 0.42, text: "healthier softmax", color: "coral")
                ])
            ],
            check: MasteryCheck(question: "If dₖ becomes four times larger, what happens to √dₖ—and why does that help softmax?", successCriteria: "The learner says √dₖ doubles and explains that dividing by it controls logit scale or avoids saturation.", transferPrompt: "Connect a changed dimension to the normalization factor and softmax behavior."),
            toolSuggestion: "manim",
            toolPayload: ToolPayload(primaryExpression: "", comparisonExpression: "", manimTemplate: "vector", conceptCaption: "Many component products combine into one attention score.")
        )
    }

    static func demoAssessment(answer: String, lesson: LessonPlan) -> AssessmentResult {
        let lower = answer.lowercased()
        let correct: Bool
        let demonstrated: [String]
        if lesson.conceptID == "function-horizontal-translation" {
            correct = lower.contains("-3") && (lower.contains("zero") || lower.contains("x + 3"))
            demonstrated = correct ? ["zeroing the inner expression", "horizontal sign direction"] : []
        } else if lesson.conceptID == "alveolar-diffusion" {
            correct = lower.contains("slow") && (lower.contains("distance") || lower.contains("thick"))
            demonstrated = correct ? ["diffusion distance controls transfer rate"] : []
        } else {
            correct = (lower.contains("double") || lower.contains("2")) && (lower.contains("softmax") || lower.contains("scale") || lower.contains("satur"))
            demonstrated = correct ? ["square-root scaling", "softmax saturation connection"] : []
        }
        return AssessmentResult(
            correct: correct,
            score: correct ? 0.92 : 0.35,
            feedback: correct ? "Yes—that reasoning transfers. You used the relationship, not just the memorized answer." : "Not quite yet. Your answer names the result, but the causal link is still missing. Let’s represent it a different way.",
            demonstrated: demonstrated,
            shakyAreas: correct ? [] : [lesson.diagnosis],
            nextStrategy: correct ? "Increase difficulty with a nearby transfer problem." : "Use a concrete visual comparison and ask for a prediction before explaining."
        )
    }
}
