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
}
