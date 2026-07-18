import Foundation

enum TutorPhase: Equatable {
    case ready
    case listening
    case seeing
    case thinking
    case teaching
    case error(String)

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .listening: return "Listening"
        case .seeing: return "Looking at your screen"
        case .thinking: return "Building your lesson"
        case .teaching: return "Teaching"
        case .error: return "Needs attention"
        }
    }
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
}

struct LessonPlan: Codable, Hashable {
    let title: String
    let spoken: String
    let note: String
    let question: String
    let toolSuggestion: String
    let annotations: [ScreenAnnotation]
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: Role
    let text: String
    let kind: Kind

    enum Role { case learner, aster }
    enum Kind { case message, insight, check }
}

struct APIUsage: Codable, Hashable {
    let inputTokens: Int
    let outputTokens: Int

    var estimatedTerraCost: Double {
        (Double(inputTokens) * 2.5 / 1_000_000) +
        (Double(outputTokens) * 15 / 1_000_000)
    }
}

struct TutorResult {
    let lesson: LessonPlan
    let usage: APIUsage
}
