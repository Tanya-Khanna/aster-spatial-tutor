import AppKit
import Foundation
import SwiftUI

@MainActor
final class TutorModel: ObservableObject {
    static let shared = TutorModel()

    @Published var phase: TutorPhase = .ready
    @Published var query = ""
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .aster, text: "Point at anything on your screen. I’ll teach it where it lives.", kind: .message)
    ]
    @Published var apiKey = KeychainStore.load()
    @Published var estimatedSpend = UserDefaults.standard.double(forKey: "estimatedSpend")
    @Published var precisionMode = false
    @Published var isListening = false
    @Published var lastLesson: LessonPlan?
    @Published var isPanelVisible = false

    var onShowPanel: (() -> Void)?
    var onHidePanel: (() -> Void)?
    var onShowWelcome: (() -> Void)?

    private let capture = ScreenCaptureService()
    private let client = OpenAIClient()
    private let voice = VoiceServices()
    private(set) var overlay = OverlayController()
    private var lastScreenFrame = NSScreen.main?.frame ?? .zero

    private init() {
        voice.onText = { [weak self] text in self?.query = text }
        voice.onFinished = { [weak self] in
            guard let self, case .teaching = self.phase else { return }
            self.phase = .ready
        }
    }

    func activate() {
        isPanelVisible = true
        onShowPanel?()
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePanel() {
        overlay.clear()
        voice.stopSpeaking()
        isPanelVisible = false
        onHidePanel?()
    }

    func saveAPIKey() { KeychainStore.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines)) }

    func toggleListening() {
        if isListening {
            voice.stopListening()
            isListening = false
            phase = .ready
        } else {
            isListening = true
            phase = .listening
            voice.startListening()
        }
    }

    func submit() {
        let question = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        if isListening { toggleListening() }
        query = ""
        messages.append(ChatMessage(role: .learner, text: question, kind: .message))
        Task { await buildLesson(for: question) }
    }

    func runDemo(_ kind: String = "paper") {
        activate()
        let question: String
        switch kind {
        case "anatomy": question = "How does oxygen move across this membrane?"
        case "graph": question = "Why does this term shift the graph to the right?"
        default: question = "Can you explain what this equation is saying intuitively?"
        }
        query = question
        submit()
    }

    private func buildLesson(for question: String) async {
        // Reserve enough room for one bounded vision request so the project never
        // discovers the limit only after it has already crossed it.
        if estimatedSpend >= 4.80 {
            phase = .error("$5 budget guard reached")
            return
        }
        phase = .seeing
        do {
            let captured = try capture.captureMainDisplay()
            lastScreenFrame = captured.screenFrame
            phase = .thinking
            let result: TutorResult
            if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try await Task.sleep(nanoseconds: 700_000_000)
                result = TutorResult(lesson: Self.demoLesson(for: question), usage: APIUsage(inputTokens: 0, outputTokens: 0))
            } else {
                result = try await client.makeLesson(
                    apiKey: apiKey,
                    question: question,
                    screen: captured,
                    recentContext: recentContext,
                    precisionMode: precisionMode
                )
            }
            estimatedSpend += result.usage.estimatedTerraCost
            UserDefaults.standard.set(estimatedSpend, forKey: "estimatedSpend")
            present(result.lesson)
        } catch {
            phase = .error(error.localizedDescription)
            messages.append(ChatMessage(role: .aster, text: error.localizedDescription, kind: .message))
        }
    }

    private func present(_ lesson: LessonPlan) {
        lastLesson = lesson
        messages.append(ChatMessage(role: .aster, text: lesson.spoken, kind: .message))
        messages.append(ChatMessage(role: .aster, text: lesson.note, kind: .insight))
        if !lesson.question.isEmpty {
            messages.append(ChatMessage(role: .aster, text: lesson.question, kind: .check))
        }
        overlay.show(lesson.annotations, on: lastScreenFrame)
        phase = .teaching
        voice.speak(lesson.spoken)
    }

    private var recentContext: String {
        messages.suffix(5).map { message in
            "\(message.role == .learner ? "Learner" : "Tutor"): \(message.text)"
        }.joined(separator: "\n")
    }

    static func demoLesson(for question: String) -> LessonPlan {
        let lower = question.lowercased()
        if lower.contains("oxygen") || lower.contains("anatom") || lower.contains("membrane") {
            return LessonPlan(
                title: "Diffusion, made visible",
                spoken: "Start with the concentration difference. Oxygen is more concentrated on one side, so random motion creates a net flow across the thin membrane toward the lower concentration.",
                note: "Net diffusion follows a concentration gradient; individual molecules still move randomly in both directions.",
                question: "If the membrane became twice as thick, would diffusion become faster or slower?",
                toolSuggestion: "none",
                annotations: [
                    ScreenAnnotation(id: "a1", type: "circle", x: 0.35, y: 0.32, width: 0.16, height: 0.2, endX: 0.51, endY: 0.42, text: "higher O₂", color: "coral"),
                    ScreenAnnotation(id: "a2", type: "arrow", x: 0.46, y: 0.43, width: 0.1, height: 0.05, endX: 0.61, endY: 0.43, text: "net diffusion", color: "violet"),
                    ScreenAnnotation(id: "a3", type: "highlight", x: 0.51, y: 0.28, width: 0.06, height: 0.3, endX: 0.57, endY: 0.43, text: "thin membrane", color: "mint")
                ]
            )
        }
        if lower.contains("graph") || lower.contains("shift") || lower.contains("desmos") {
            return LessonPlan(
                title: "Read the transformation from the inside",
                spoken: "The subtraction happens before squaring, so the input must reach two before the squared part becomes zero. That moves the vertex to the right, not the left.",
                note: "Inside changes act on inputs: x minus h shifts a graph right by h.",
                question: "Where would the vertex move if the expression were x plus three?",
                toolSuggestion: "desmos",
                annotations: [
                    ScreenAnnotation(id: "g1", type: "highlight", x: 0.38, y: 0.39, width: 0.12, height: 0.08, endX: 0.5, endY: 0.43, text: "input becomes zero at x = 2", color: "violet"),
                    ScreenAnnotation(id: "g2", type: "arrow", x: 0.45, y: 0.56, width: 0.1, height: 0.04, endX: 0.61, endY: 0.56, text: "right 2", color: "blue")
                ]
            )
        }
        return LessonPlan(
            title: "Follow the structure",
            spoken: "Read this as a balance between two ideas. The left side describes how the quantity changes; the right side tells you what causes that change. Let’s connect each symbol before manipulating the equation.",
            note: "Name the role of every term before doing algebra. Structure comes before calculation.",
            question: "Which symbol represents the quantity that is changing?",
            toolSuggestion: "none",
            annotations: [
                ScreenAnnotation(id: "p1", type: "circle", x: 0.27, y: 0.31, width: 0.18, height: 0.08, endX: 0.45, endY: 0.35, text: "rate of change", color: "violet"),
                ScreenAnnotation(id: "p2", type: "highlight", x: 0.52, y: 0.31, width: 0.2, height: 0.08, endX: 0.72, endY: 0.35, text: "what drives it", color: "mint")
            ]
        )
    }
}
