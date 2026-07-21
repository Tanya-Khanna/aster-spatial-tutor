import CoreGraphics
import Foundation

enum APIKeyStatus: Equatable {
    case unauthenticated
    case validating
    case authenticated(hint: String)
    case invalid(message: String)

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}

enum OnboardingStep: Int, CaseIterable {
    case introduction
    case permissions
    case apiKey
    case ready
}

enum PermissionState: Equatable {
    case notDetermined
    case granted
    case denied

    var label: String {
        switch self {
        case .notDetermined: return "Not requested"
        case .granted: return "Allowed"
        case .denied: return "Needs attention"
        }
    }
}

struct APIUsage: Equatable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var totalTokens: Int = 0

    static let zero = APIUsage()

    mutating func add(_ usage: APIUsage) {
        inputTokens += usage.inputTokens
        outputTokens += usage.outputTokens
        totalTokens += usage.totalTokens
    }
}

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

/// A stable, display-aware description of what the learner selected. Regions are
/// stored relative to a display or window so they survive Retina scaling and moves.
struct CaptureTarget: Codable, Hashable {
    enum Kind: String, Codable { case displayRegion, window }

    var kind: Kind
    var displayID: UInt32
    var region: ContextRegion
    var windowID: UInt32?
    var appName: String
    var windowTitle: String
    var anchor: SemanticAnchor?

    static func displayRegion(displayID: UInt32, region: ContextRegion) -> CaptureTarget {
        CaptureTarget(kind: .displayRegion, displayID: displayID, region: region, windowID: nil, appName: "", windowTitle: "", anchor: nil)
    }
}

struct SemanticAnchor: Codable, Hashable {
    var label: String
    var bounds: ContextRegion
    var confidence: Double
    var fingerprint: String
    var lastResolvedAt: Date
}

struct VideoContext: Codable, Hashable {
    var sourceTitle: String
    var currentTime: Double
    var isPaused: Bool
    var captions: String
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

enum ActionPermission: String, Codable, CaseIterable, Identifiable {
    case askEveryTime
    case internalOnly
    case never
    var id: String { rawValue }

    var label: String {
        switch self {
        case .askEveryTime: return "Ask every time"
        case .internalOnly: return "Internal teaching tools only"
        case .never: return "Never"
        }
    }
}

struct TutorActionRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let kind: String
    let summary: String
    let reversible: Bool
}

struct LearningEvidence: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let score: Double
    let demonstrated: [String]
    let shakyAreas: [String]
}

struct LearnerPreferences: Codable, Hashable {
    var analogyStyle: String
    var explanationMode: String
    var difficulty: Double
    var narrationRate: Double

    static let standard = LearnerPreferences(
        analogyStyle: "concrete and visual",
        explanationMode: "intuitive",
        difficulty: 0.5,
        narrationRate: 0.48
    )
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

struct DiagramPrimitive: Codable, Identifiable, Hashable {
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

struct LessonStep: Codable, Identifiable, Hashable {
    let id: String
    let narration: String
    let notebook: String
    let annotations: [ScreenAnnotation]
    let visualMode: String
    let diagramPrimitives: [DiagramPrimitive]

    init(
        id: String,
        narration: String,
        notebook: String,
        annotations: [ScreenAnnotation],
        visualMode: String = "overlay",
        diagramPrimitives: [DiagramPrimitive] = []
    ) {
        self.id = id; self.narration = narration; self.notebook = notebook
        self.annotations = annotations; self.visualMode = visualMode; self.diagramPrimitives = diagramPrimitives
    }

    enum CodingKeys: String, CodingKey { case id, narration, notebook, annotations, visualMode, diagramPrimitives }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        narration = try c.decode(String.self, forKey: .narration)
        notebook = try c.decode(String.self, forKey: .notebook)
        annotations = try c.decode([ScreenAnnotation].self, forKey: .annotations)
        visualMode = try c.decodeIfPresent(String.self, forKey: .visualMode) ?? "overlay"
        diagramPrimitives = try c.decodeIfPresent([DiagramPrimitive].self, forKey: .diagramPrimitives) ?? []
    }
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
    var nextReview: Date = Date()
    var reviewIntervalDays: Double = 1
    var difficulty: Double = 0.5
    var dependencies: [String] = []
    var misconceptionCluster: String = ""
    var evidence: [LearningEvidence] = []

    var statusLabel: String {
        if mastery >= 0.82 { return "Mastered" }
        if mastery >= 0.55 { return "Developing" }
        return "Needs practice"
    }

    var isReviewDue: Bool { nextReview <= Date() }

    enum CodingKeys: String, CodingKey {
        case id, title, mastery, attempts, correctAttempts, understood, shakyAreas, nextStrategy, lastSeen
        case nextReview, reviewIntervalDays, difficulty, dependencies, misconceptionCluster, evidence
    }

    init(
        id: String, title: String, mastery: Double, attempts: Int, correctAttempts: Int,
        understood: [String], shakyAreas: [String], nextStrategy: String, lastSeen: Date,
        nextReview: Date = Date(), reviewIntervalDays: Double = 1, difficulty: Double = 0.5,
        dependencies: [String] = [], misconceptionCluster: String = "", evidence: [LearningEvidence] = []
    ) {
        self.id = id; self.title = title; self.mastery = mastery; self.attempts = attempts
        self.correctAttempts = correctAttempts; self.understood = understood; self.shakyAreas = shakyAreas
        self.nextStrategy = nextStrategy; self.lastSeen = lastSeen; self.nextReview = nextReview
        self.reviewIntervalDays = reviewIntervalDays; self.difficulty = difficulty
        self.dependencies = dependencies; self.misconceptionCluster = misconceptionCluster; self.evidence = evidence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        mastery = try c.decode(Double.self, forKey: .mastery)
        attempts = try c.decode(Int.self, forKey: .attempts)
        correctAttempts = try c.decode(Int.self, forKey: .correctAttempts)
        understood = try c.decode([String].self, forKey: .understood)
        shakyAreas = try c.decode([String].self, forKey: .shakyAreas)
        nextStrategy = try c.decode(String.self, forKey: .nextStrategy)
        lastSeen = try c.decode(Date.self, forKey: .lastSeen)
        nextReview = try c.decodeIfPresent(Date.self, forKey: .nextReview) ?? Date()
        reviewIntervalDays = try c.decodeIfPresent(Double.self, forKey: .reviewIntervalDays) ?? 1
        difficulty = try c.decodeIfPresent(Double.self, forKey: .difficulty) ?? 0.5
        dependencies = try c.decodeIfPresent([String].self, forKey: .dependencies) ?? []
        misconceptionCluster = try c.decodeIfPresent(String.self, forKey: .misconceptionCluster) ?? ""
        evidence = try c.decodeIfPresent([LearningEvidence].self, forKey: .evidence) ?? []
    }
}

struct LearnerProfile: Codable, Hashable {
    var concepts: [ConceptMemory]
    var totalChecks: Int
    var streak: Int
    var preferences: LearnerPreferences = .standard

    static let empty = LearnerProfile(concepts: [], totalChecks: 0, streak: 0, preferences: .standard)

    func memory(for conceptID: String) -> ConceptMemory? {
        concepts.first(where: { $0.id == conceptID })
    }

    var dueReviews: [ConceptMemory] {
        concepts.filter(\.isReviewDue).sorted { $0.nextReview < $1.nextReview }
    }

    enum CodingKeys: String, CodingKey { case concepts, totalChecks, streak, preferences }

    init(concepts: [ConceptMemory], totalChecks: Int, streak: Int, preferences: LearnerPreferences = .standard) {
        self.concepts = concepts; self.totalChecks = totalChecks; self.streak = streak; self.preferences = preferences
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        concepts = try c.decodeIfPresent([ConceptMemory].self, forKey: .concepts) ?? []
        totalChecks = try c.decodeIfPresent(Int.self, forKey: .totalChecks) ?? 0
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        preferences = try c.decodeIfPresent(LearnerPreferences.self, forKey: .preferences) ?? .standard
    }

    var promptSummary: String {
        let preferenceLine = "Preferences: mode \(preferences.explanationMode); analogy \(preferences.analogyStyle); difficulty \(Int(preferences.difficulty * 100))%."
        guard !concepts.isEmpty else { return "\(preferenceLine) No prior mastery evidence yet." }
        return preferenceLine + "\n" + concepts
            .sorted { $0.lastSeen > $1.lastSeen }
            .prefix(8)
            .map { concept in
                "\(concept.title): mastery \(Int(concept.mastery * 100))%; understands [\(concept.understood.joined(separator: ", "))]; shaky [\(concept.shakyAreas.joined(separator: ", "))]; dependencies [\(concept.dependencies.joined(separator: ", "))]; next [\(concept.nextStrategy)]; review \(concept.nextReview.formatted())"
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

struct TutorResult<Value> {
    let value: Value
    let usage: APIUsage
}
