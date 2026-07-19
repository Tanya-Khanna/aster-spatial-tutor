import Foundation

enum TutorAPIError: LocalizedError {
    case invalidResponse
    case service(String)
    case budgetReached

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Aster received an incomplete teaching plan. Try once more."
        case .service(let message): return message
        case .budgetReached: return "Your $5 project budget guard has been reached."
        }
    }
}

final class OpenAIClient {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    func diagnose(
        apiKey: String,
        question: String,
        screen: CapturedScreen,
        recentFrames: [CapturedScreen] = [],
        recentContext: String,
        learnerMemory: String,
        safetyIdentifier: String
    ) async throws -> TutorResult<DiagnosticPlan> {
        let prompt = """
        Learner question: \(question)

        Recent notebook:
        \(recentContext.isEmpty ? "No current-session notes." : recentContext)

        Persistent learner memory:
        \(learnerMemory)

        The newest image is the exact context the learner selected. A violet cursor halo indicates the object they mean. If multiple timestamped frames are present, reason about what changed across the sequence; do not treat them as unrelated images.
        Before teaching, identify the visible object and ask ONE short diagnostic question with 2–3 concrete options that distinguish likely misconceptions. Do not explain or solve yet. Use priorConnection only when the stored evidence genuinely supports it; otherwise leave it empty. Use a stable lowercase conceptID such as function-horizontal-translation or attention-scaling.
        """
        return try await structuredRequest(
            apiKey: apiKey,
            model: "gpt-5.6-terra",
            reasoningEffort: "low",
            instructions: Self.diagnosticInstructions,
            prompt: prompt,
            images: recentFrames.isEmpty ? [screen] : recentFrames,
            imageDetail: "original",
            maxOutputTokens: 500,
            format: Self.diagnosticFormat,
            safetyIdentifier: safetyIdentifier
        )
    }

    func makeLesson(
        apiKey: String,
        originalQuestion: String,
        selectedDiagnosis: DiagnosticOption,
        diagnostic: DiagnosticPlan,
        screen: CapturedScreen,
        recentFrames: [CapturedScreen] = [],
        recentContext: String,
        learnerMemory: String,
        precisionMode: Bool,
        safetyIdentifier: String
    ) async throws -> TutorResult<LessonPlan> {
        let model = precisionMode ? "gpt-5.6-sol" : "gpt-5.6-terra"
        let prompt = """
        Original question: \(originalQuestion)
        Visible object: \(diagnostic.observedObject)
        Learner selected: \(selectedDiagnosis.label)
        Diagnosed misconception: \(selectedDiagnosis.misconception)
        Concept ID: \(diagnostic.conceptID)
        Concept title: \(diagnostic.conceptTitle)
        Prior connection: \(diagnostic.priorConnection)

        Recent notebook:
        \(recentContext)

        Persistent learner memory:
        \(learnerMemory)

        Build a synchronized spatial lesson over the newest selected image. Use 1–4 short steps. Every step must coordinate narration, one notebook insight, and 0–4 precise annotations. Coordinates are normalized 0...1 relative to THIS CROPPED IMAGE, origin TOP LEFT. Reveal only what advances that step. Prefer arrows for relationships, circles for one object, highlights for a span, labels beside—not over—the source, flow for changing processes, and focus to dim irrelevant regions. For a genuinely dense diagram, set visualMode to simplify and redraw its essential causal structure with up to 8 safe diagramPrimitives (line, arrow, node, box, text); otherwise return an empty array. Use compare to show two instructional states. If multiple frames are present, explain the change or process across time and anchor the final annotations to the newest frame. If localization is uncertain, use fewer marks and say where the learner should point more tightly.

        Coverage includes equations, research papers, charts, circuits, molecular diagrams, geometry proofs, engineering schematics, anatomy diagrams, data visualizations, and code. End with an independent prediction or transfer question. Do not give the answer to that check. Never complete a graded-looking problem. Suggest desmos only when graphing materially improves the prediction–demonstration loop. Suggest manim only for a bounded local template. Tool payloads are data, never executable code.
        """
        return try await structuredRequest(
            apiKey: apiKey,
            model: model,
            reasoningEffort: precisionMode ? "medium" : "low",
            instructions: Self.lessonInstructions,
            prompt: prompt,
            images: recentFrames.isEmpty ? [screen] : recentFrames,
            imageDetail: precisionMode ? "original" : "high",
            maxOutputTokens: 1_400,
            format: Self.lessonFormat,
            safetyIdentifier: safetyIdentifier
        )
    }

    func assess(
        apiKey: String,
        lesson: LessonPlan,
        learnerAnswer: String,
        learnerMemory: String,
        safetyIdentifier: String
    ) async throws -> TutorResult<AssessmentResult> {
        let prompt = """
        Concept: \(lesson.conceptTitle) (\(lesson.conceptID))
        Diagnosis: \(lesson.diagnosis)
        Independent check: \(lesson.check.question)
        Success criteria: \(lesson.check.successCriteria)
        Transfer goal: \(lesson.check.transferPrompt)
        Learner answer: \(learnerAnswer)

        Existing memory:
        \(learnerMemory)

        Evaluate conceptual understanding, not exact wording. Give concise feedback without revealing more than necessary. Score from 0 to 1. Record only abilities evidenced by this answer. Name remaining shaky areas specifically. nextStrategy must tell the next tutor turn how to teach differently if needed.
        """
        return try await structuredRequest(
            apiKey: apiKey,
            model: "gpt-5.6-luna",
            reasoningEffort: "low",
            instructions: Self.assessmentInstructions,
            prompt: prompt,
            images: [],
            imageDetail: "low",
            maxOutputTokens: 450,
            format: Self.assessmentFormat,
            safetyIdentifier: safetyIdentifier
        )
    }

    private func structuredRequest<Value: Decodable>(
        apiKey: String,
        model: String,
        reasoningEffort: String,
        instructions: String,
        prompt: String,
        images: [CapturedScreen],
        imageDetail: String,
        maxOutputTokens: Int,
        format: [String: Any],
        safetyIdentifier: String
    ) async throws -> TutorResult<Value> {
        var content: [[String: Any]] = [["type": "input_text", "text": prompt]]
        for (index, image) in images.suffix(4).enumerated() {
            let age = max(0, Date().timeIntervalSince(image.capturedAt))
            content.append(["type": "input_text", "text": "Frame \(index + 1), captured \(String(format: "%.1f", age)) seconds ago\(image.videoContext.map { ", video time \(String(format: "%.1f", $0.currentTime))s, captions: \($0.captions)" } ?? "")."])
            content.append([
                "type": "input_image",
                "image_url": "data:image/jpeg;base64,\(image.jpegData.base64EncodedString())",
                "detail": index == images.suffix(4).count - 1 ? imageDetail : "low"
            ])
        }

        let requestBody: [String: Any] = [
            "model": model,
            "store": false,
            "safety_identifier": safetyIdentifier,
            "reasoning": ["effort": reasoningEffort],
            "max_output_tokens": maxOutputTokens,
            "instructions": instructions,
            "input": [["role": "user", "content": content]],
            "text": ["verbosity": "low", "format": format]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 55
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
              let messageContent = message["content"] as? [[String: Any]],
              let outputText = messageContent.first(where: { $0["type"] as? String == "output_text" })?["text"] as? String,
              let valueData = outputText.data(using: .utf8) else {
            throw TutorAPIError.invalidResponse
        }

        let value = try JSONDecoder().decode(Value.self, from: valueData)
        let usageObject = root["usage"] as? [String: Any]
        let usage = APIUsage(
            inputTokens: usageObject?["input_tokens"] as? Int ?? 0,
            outputTokens: usageObject?["output_tokens"] as? Int ?? 0
        )
        return TutorResult(value: value, usage: usage, model: model)
    }

    private static let diagnosticInstructions = """
    You are Aster's diagnostic tutor. Inspect the learner's selected visual context and determine what must be clarified before an explanation. Ask exactly one short, non-leading question with concrete options. Do not teach, solve, or annotate yet. Connect to persistent mastery evidence only when it is explicitly present.
    """

    private static let lessonInstructions = """
    You are Aster, a calm spatial STEM tutor. Teach one causal or structural idea at a time in intuitive language. Voice is the teacher; notebook text preserves only the key insight; annotations point to the exact visible evidence. Scaffold rather than solve. End with an independent check. For anatomy, teach only labeled educational diagrams and never diagnose or interpret clinical imagery.
    """

    private static let assessmentInstructions = """
    You are Aster's understanding checker. Judge the learner's reasoning against the stated success criteria. Be generous about phrasing and strict about the central concept. Update memory only from demonstrated evidence. If incorrect, identify one precise shaky area and a different next teaching strategy.
    """

    private static let diagnosticFormat: [String: Any] = [
        "type": "json_schema", "name": "diagnostic_plan", "strict": true,
        "schema": [
            "type": "object", "additionalProperties": false,
            "properties": [
                "conceptID": ["type": "string"],
                "conceptTitle": ["type": "string"],
                "observedObject": ["type": "string"],
                "question": ["type": "string"],
                "options": [
                    "type": "array", "minItems": 2, "maxItems": 3,
                    "items": [
                        "type": "object", "additionalProperties": false,
                        "properties": [
                            "id": ["type": "string"],
                            "label": ["type": "string"],
                            "misconception": ["type": "string"]
                        ],
                        "required": ["id", "label", "misconception"]
                    ]
                ],
                "priorConnection": ["type": "string"]
            ],
            "required": ["conceptID", "conceptTitle", "observedObject", "question", "options", "priorConnection"]
        ]
    ]

    private static let annotationProperties: [String: Any] = [
        "id": ["type": "string"],
        "type": ["type": "string", "enum": ["circle", "highlight", "arrow", "label", "mask", "flow", "focus", "comparison"]],
        "x": ["type": "number", "minimum": 0, "maximum": 1],
        "y": ["type": "number", "minimum": 0, "maximum": 1],
        "width": ["type": "number", "minimum": 0, "maximum": 1],
        "height": ["type": "number", "minimum": 0, "maximum": 1],
        "endX": ["type": "number", "minimum": 0, "maximum": 1],
        "endY": ["type": "number", "minimum": 0, "maximum": 1],
        "text": ["type": "string"],
        "color": ["type": "string", "enum": ["violet", "mint", "coral", "blue"]]
    ]

    private static let lessonFormat: [String: Any] = [
        "type": "json_schema", "name": "spatial_lesson", "strict": true,
        "schema": [
            "type": "object", "additionalProperties": false,
            "properties": [
                "title": ["type": "string"],
                "conceptID": ["type": "string"],
                "conceptTitle": ["type": "string"],
                "diagnosis": ["type": "string"],
                "steps": [
                    "type": "array", "minItems": 1, "maxItems": 4,
                    "items": [
                        "type": "object", "additionalProperties": false,
                        "properties": [
                            "id": ["type": "string"],
                            "narration": ["type": "string"],
                            "notebook": ["type": "string"],
                            "annotations": [
                                "type": "array", "maxItems": 4,
                                "items": [
                                    "type": "object", "additionalProperties": false,
                                    "properties": annotationProperties,
                                    "required": ["id", "type", "x", "y", "width", "height", "endX", "endY", "text", "color"]
                                ]
                            ],
                            "visualMode": ["type": "string", "enum": ["overlay", "simplify", "compare"]],
                            "diagramPrimitives": [
                                "type": "array", "maxItems": 8,
                                "items": [
                                    "type": "object", "additionalProperties": false,
                                    "properties": [
                                        "id": ["type": "string"],
                                        "type": ["type": "string", "enum": ["line", "arrow", "node", "box", "text"]],
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
                        "required": ["id", "narration", "notebook", "annotations", "visualMode", "diagramPrimitives"]
                    ]
                ],
                "check": [
                    "type": "object", "additionalProperties": false,
                    "properties": [
                        "question": ["type": "string"],
                        "successCriteria": ["type": "string"],
                        "transferPrompt": ["type": "string"]
                    ],
                    "required": ["question", "successCriteria", "transferPrompt"]
                ],
                "toolSuggestion": ["type": "string", "enum": ["none", "desmos", "manim"]],
                "toolPayload": [
                    "type": "object", "additionalProperties": false,
                    "properties": [
                        "primaryExpression": ["type": "string"],
                        "comparisonExpression": ["type": "string"],
                        "manimTemplate": ["type": "string", "enum": ["none", "derivative", "vector", "matrix", "circuit", "limit", "field", "geometry", "wave", "molecule"]],
                        "conceptCaption": ["type": "string"]
                    ],
                    "required": ["primaryExpression", "comparisonExpression", "manimTemplate", "conceptCaption"]
                ]
            ],
            "required": ["title", "conceptID", "conceptTitle", "diagnosis", "steps", "check", "toolSuggestion", "toolPayload"]
        ]
    ]

    private static let assessmentFormat: [String: Any] = [
        "type": "json_schema", "name": "mastery_assessment", "strict": true,
        "schema": [
            "type": "object", "additionalProperties": false,
            "properties": [
                "correct": ["type": "boolean"],
                "score": ["type": "number", "minimum": 0, "maximum": 1],
                "feedback": ["type": "string"],
                "demonstrated": ["type": "array", "maxItems": 4, "items": ["type": "string"]],
                "shakyAreas": ["type": "array", "maxItems": 4, "items": ["type": "string"]],
                "nextStrategy": ["type": "string"]
            ],
            "required": ["correct", "score", "feedback", "demonstrated", "shakyAreas", "nextStrategy"]
        ]
    ]
}
