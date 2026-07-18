import CoreGraphics
import Foundation

enum TutorPhase: Equatable {
    case ready
    case selectingContext
    case following
    case listening
    case seeing
    case diagnosing
    case clarifying
    case thinking
    case teaching
    case awaitingUnderstanding
    case assessing
    case runningTool
    case error(String)

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .selectingContext: return "Select the exact learning context"
        case .following: return "Following the selected context"
        case .listening: return "Listening"
        case .seeing: return "Reading the selected context"
        case .diagnosing: return "Finding the point of confusion"
        case .clarifying: return "Waiting for your diagnosis choice"
        case .thinking: return "Planning one teaching step"
        case .teaching: return "Teaching spatially"
        case .awaitingUnderstanding: return "Your turn"
        case .assessing: return "Checking understanding"
        case .runningTool: return "Preparing a demonstration"
        case .error: return "Needs attention"
        }
    }
}

struct ContextRegion: Codable, Hashable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    static let fullScreen = ContextRegion(x: 0, y: 0, width: 1, height: 1)

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
        self.width = min(max(width, 0.02), 1 - self.x)
        self.height = min(max(height, 0.02), 1 - self.y)
    }

    init(normalized rect: CGRect) {
        self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }

    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

struct DiagnosticOption: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let misconception: String
}

struct DiagnosticPlan: Codable, Hashable {
    let conceptID: String
    let conceptTitle: String
    let observedObject: String
    let question: String
    let options: [DiagnosticOption]
    let priorConnection: String
}

struct ScreenAnnotation: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let endX: Double
    let endY: Double
    let text: String
    let color: String

    var clamped: ScreenAnnotation {
        ScreenAnnotation(
            id: id,
            type: type,
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1),
            width: min(max(width, 0.01), 1),
            height: min(max(height, 0.01), 1),
            endX: min(max(endX, 0), 1),
            endY: min(max(endY, 0), 1),
            text: String(text.prefix(80)),
            color: color
        )
    }
}

enum AnnotationGeometry {
    static func normalizedRect(for annotation: ScreenAnnotation, within region: ContextRegion) -> CGRect {
        CGRect(
            x: region.x + annotation.x * region.width,
            y: region.y + annotation.y * region.height,
            width: annotation.width * region.width,
            height: annotation.height * region.height
        )
    }

    static func normalizedPoint(x: Double, y: Double, within region: ContextRegion) -> CGPoint {
        CGPoint(x: region.x + x * region.width, y: region.y + y * region.height)
    }
}

struct LessonStep: Codable, Identifiable, Hashable {
    let id: String
    let narration: String
    let notebook: String
    let annotations: [ScreenAnnotation]
}

struct MasteryCheck: Codable, Hashable {
    let question: String
    let successCriteria: String
    let transferPrompt: String
}

struct ToolPayload: Codable, Hashable {
    let primaryExpression: String
    let comparisonExpression: String
    let manimTemplate: String
    let conceptCaption: String
}

struct LessonPlan: Codable, Hashable {
    let title: String
    let conceptID: String
    let conceptTitle: String
    let diagnosis: String
    let steps: [LessonStep]
    let check: MasteryCheck
    let toolSuggestion: String
    let toolPayload: ToolPayload
}

struct AssessmentResult: Codable, Hashable {
    let correct: Bool
    let score: Double
    let feedback: String
    let demonstrated: [String]
    let shakyAreas: [String]
    let nextStrategy: String
}

struct ConceptMemory: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var mastery: Double
    var attempts: Int
    var correctAttempts: Int
    var understood: [String]
    var shakyAreas: [String]
    var nextStrategy: String
    var lastSeen: Date

    var statusLabel: String {
        if mastery >= 0.82 { return "Mastered" }
        if mastery >= 0.55 { return "Developing" }
        return "Needs practice"
    }
}

struct LearnerProfile: Codable, Hashable {
    var concepts: [ConceptMemory]
    var totalChecks: Int
    var streak: Int

    static let empty = LearnerProfile(concepts: [], totalChecks: 0, streak: 0)

    func memory(for conceptID: String) -> ConceptMemory? {
        concepts.first(where: { $0.id == conceptID })
    }

    var promptSummary: String {
        guard !concepts.isEmpty else { return "No prior mastery evidence yet." }
        return concepts
            .sorted { $0.lastSeen > $1.lastSeen }
            .prefix(8)
            .map { concept in
                "\(concept.title): mastery \(Int(concept.mastery * 100))%; understands [\(concept.understood.joined(separator: ", "))]; shaky [\(concept.shakyAreas.joined(separator: ", "))]; next [\(concept.nextStrategy)]"
            }
            .joined(separator: "\n")
    }
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: Role
    let text: String
    let kind: Kind

    enum Role { case learner, aster }
    enum Kind { case message, diagnostic, insight, check, assessment, memory, tool }
}

struct APIUsage: Codable, Hashable {
    let inputTokens: Int
    let outputTokens: Int

    func estimatedCost(model: String) -> Double {
        let prices: (input: Double, output: Double)
        if model.contains("luna") { prices = (1, 6) }
        else if model.contains("sol") { prices = (5, 30) }
        else { prices = (2.5, 15) }
        return (Double(inputTokens) * prices.input / 1_000_000) +
            (Double(outputTokens) * prices.output / 1_000_000)
    }
}

struct TutorResult<Value> {
    let value: Value
    let usage: APIUsage
    let model: String
}
