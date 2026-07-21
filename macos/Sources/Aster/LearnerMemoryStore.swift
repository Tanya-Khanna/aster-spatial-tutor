import Foundation

final class LearnerMemoryStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = base.appendingPathComponent("Aster", isDirectory: true).appendingPathComponent("learner-profile.json")
        }
    }

    func load() -> LearnerProfile {
        guard let data = try? Data(contentsOf: fileURL) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let profile = try? decoder.decode(LearnerProfile.self, from: data) else {
            return .empty
        }
        return profile
    }

    func save(_ profile: LearnerProfile) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(profile).write(to: fileURL, options: .atomic)
        } catch {
            // Memory should never interrupt the current lesson. The next save retries.
        }
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func update(
        profile: LearnerProfile,
        conceptID: String,
        title: String,
        assessment: AssessmentResult
    ) -> LearnerProfile {
        var result = profile
        var concept = result.memory(for: conceptID) ?? ConceptMemory(
            id: conceptID,
            title: title,
            mastery: 0.25,
            attempts: 0,
            correctAttempts: 0,
            understood: [],
            shakyAreas: [],
            nextStrategy: "Begin with a concrete visual explanation.",
            lastSeen: Date()
        )

        concept.title = title
        concept.attempts += 1
        if assessment.correct { concept.correctAttempts += 1 }
        let evidenceWeight = concept.attempts == 1 ? 0.55 : 0.35
        concept.mastery = min(max((1 - evidenceWeight) * concept.mastery + evidenceWeight * assessment.score, 0), 1)
        concept.understood = Self.merged(concept.understood, assessment.demonstrated)
        concept.shakyAreas = Self.merged(
            concept.shakyAreas.filter { !assessment.demonstrated.contains($0) },
            assessment.shakyAreas
        )
        concept.nextStrategy = assessment.nextStrategy
        concept.lastSeen = Date()
        concept.difficulty = min(max(1 - assessment.score, 0.15), 0.95)
        concept.misconceptionCluster = Self.cluster(for: assessment.shakyAreas)
        concept.dependencies = Self.merged(concept.dependencies, Self.dependencies(for: conceptID))
        concept.evidence = Array((concept.evidence + [LearningEvidence(
            id: UUID(),
            date: Date(),
            score: assessment.score,
            demonstrated: assessment.demonstrated,
            shakyAreas: assessment.shakyAreas
        )]).suffix(30))

        // A compact SM-2-inspired schedule. Correct transfer expands the interval;
        // shaky evidence brings the concept back tomorrow.
        if assessment.correct && assessment.score >= 0.75 {
            let multiplier = 1.8 + assessment.score
            concept.reviewIntervalDays = min(max(concept.reviewIntervalDays * multiplier, 2), 60)
        } else {
            concept.reviewIntervalDays = 1
        }
        concept.nextReview = Calendar.current.date(
            byAdding: .minute,
            value: Int(concept.reviewIntervalDays * 24 * 60),
            to: Date()
        ) ?? Date().addingTimeInterval(86_400)

        if let index = result.concepts.firstIndex(where: { $0.id == conceptID }) {
            result.concepts[index] = concept
        } else {
            result.concepts.append(concept)
        }
        result.totalChecks += 1
        result.streak = assessment.correct ? result.streak + 1 : 0
        save(result)
        return result
    }

    private static func merged(_ existing: [String], _ new: [String]) -> [String] {
        var values: [String] = []
        for value in existing + new where !value.isEmpty && !values.contains(value) {
            values.append(value)
        }
        return Array(values.suffix(6))
    }

    private static func cluster(for areas: [String]) -> String {
        let text = areas.joined(separator: " ").lowercased()
        if text.contains("sign") || text.contains("direction") { return "direction-and-sign" }
        if text.contains("dimension") || text.contains("unit") || text.contains("scal") { return "scale-and-dimensions" }
        if text.contains("cause") || text.contains("why") { return "causal-mechanism" }
        if text.contains("location") || text.contains("where") || text.contains("spatial") { return "spatial-tracking" }
        return areas.isEmpty ? "" : "conceptual-link"
    }

    private static func dependencies(for conceptID: String) -> [String] {
        let id = conceptID.lowercased()
        if id.contains("attention") { return ["dot-products", "variance", "softmax"] }
        if id.contains("translation") || id.contains("function") { return ["coordinate-plane", "function-inputs"] }
        if id.contains("diffusion") { return ["concentration-gradient", "membrane-structure"] }
        if id.contains("circuit") { return ["charge-conservation", "ohms-law"] }
        if id.contains("derivative") || id.contains("limit") { return ["function-change", "limits"] }
        if id.contains("molecule") || id.contains("chem") { return ["atomic-structure", "bonding"] }
        return []
    }
}
