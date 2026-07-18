import Foundation

enum TutorAPIError: LocalizedError {
    case invalidResponse
    case service(String)
    case budgetReached

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The lesson response was incomplete. Try once more."
        case .service(let message): return message
        case .budgetReached: return "Your $5 demo budget limit has been reached."
        }
    }
}

final class OpenAIClient {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    func makeLesson(
        apiKey: String,
        question: String,
        screen: CapturedScreen,
        recentContext: String,
        precisionMode: Bool
    ) async throws -> TutorResult {
        let model = precisionMode ? "gpt-5.6-sol" : "gpt-5.6-terra"
        let prompt = """
        The learner asked: \(question)

        Recent lesson context:
        \(recentContext.isEmpty ? "No prior context." : recentContext)

        The attached image is the learner's current Mac screen. A violet cursor halo marks what they may be pointing at. Build one short teaching turn. Diagnose before solving. Use at most 4 precise annotations. Coordinates are normalized 0...1 relative to the image with origin at TOP LEFT. If localization is uncertain, use fewer annotations and ask the learner to point again. Never pretend certainty. For graded-looking work, teach the next concept rather than giving the final answer. Recommend desmos only when graphing materially helps; recommend manim only when temporal animation materially helps.
        """

        let requestBody: [String: Any] = [
            "model": model,
            "store": false,
            "reasoning": ["effort": precisionMode ? "medium" : "low"],
            "max_output_tokens": 900,
            "instructions": Self.tutorInstructions,
            "input": [[
                "role": "user",
                "content": [
                    ["type": "input_text", "text": prompt],
                    [
                        "type": "input_image",
                        "image_url": "data:image/jpeg;base64,\(screen.jpegData.base64EncodedString())",
                        "detail": precisionMode ? "original" : "high"
                    ]
                ]
            ]],
            "text": ["format": Self.lessonFormat]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TutorAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let error = object?["error"] as? [String: Any]
            let message = error?["message"] as? String ?? "OpenAI returned status \(http.statusCode)."
            throw TutorAPIError.service(message)
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = root["output"] as? [[String: Any]],
              let message = output.first(where: { $0["type"] as? String == "message" }),
              let content = message["content"] as? [[String: Any]],
              let outputText = content.first(where: { $0["type"] as? String == "output_text" })?["text"] as? String,
              let lessonData = outputText.data(using: .utf8) else {
            throw TutorAPIError.invalidResponse
        }

        let lesson = try JSONDecoder().decode(LessonPlan.self, from: lessonData)
        let usageObject = root["usage"] as? [String: Any]
        let usage = APIUsage(
            inputTokens: usageObject?["input_tokens"] as? Int ?? 0,
            outputTokens: usageObject?["output_tokens"] as? Int ?? 0
        )
        return TutorResult(lesson: lesson, usage: usage)
    }

    private static let tutorInstructions = """
    You are Aster, a calm spatial STEM tutor. Teach in the learner's visual context. Speak in short, intuitive sentences. First identify the exact visual object and likely misconception. Prefer a question, analogy, or single next step over a completed solution. Coordinate voice, note, and annotations. The spoken field is narration; the note field is a compact notebook takeaway; the question field checks understanding. Never diagnose disease or interpret radiology. For anatomy, teach only labeled educational diagrams and clearly separate structure from clinical advice.
    """

    private static let lessonFormat: [String: Any] = [
        "type": "json_schema",
        "name": "spatial_lesson",
        "strict": true,
        "schema": [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "title": ["type": "string"],
                "spoken": ["type": "string"],
                "note": ["type": "string"],
                "question": ["type": "string"],
                "toolSuggestion": ["type": "string", "enum": ["none", "desmos", "manim"]],
                "annotations": [
                    "type": "array",
                    "maxItems": 4,
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "id": ["type": "string"],
                            "type": ["type": "string", "enum": ["circle", "highlight", "arrow", "label"]],
                            "x": ["type": "number", "minimum": 0, "maximum": 1],
                            "y": ["type": "number", "minimum": 0, "maximum": 1],
                            "width": ["type": "number", "minimum": 0, "maximum": 1],
                            "height": ["type": "number", "minimum": 0, "maximum": 1],
                            "endX": ["type": "number", "minimum": 0, "maximum": 1],
                            "endY": ["type": "number", "minimum": 0, "maximum": 1],
                            "text": ["type": "string"],
                            "color": ["type": "string", "enum": ["violet", "mint", "coral", "blue"]]
                        ],
                        "required": ["id", "type", "x", "y", "width", "height", "endX", "endY", "text", "color"]
                    ]
                ]
            ],
            "required": ["title", "spoken", "note", "question", "toolSuggestion", "annotations"]
        ]
    ]
}
