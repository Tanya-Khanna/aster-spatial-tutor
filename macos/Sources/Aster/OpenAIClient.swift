import AppKit
import Foundation
import ImageIO

enum TutorAPIError: LocalizedError {
    case invalidResponse
    case authentication
    case service(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Aster✱ received an incomplete teaching plan. Try once more."
        case .authentication: return "That OpenAI API key could not be authenticated. Check the key and try again."
        case .service(let message): return message
        }
    }
}

final class OpenAIClient {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    private let modelsEndpoint = URL(string: "https://api.openai.com/v1/models")!

    static func hasPlausibleAPIKeyFormat(_ value: String) -> Bool {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.hasPrefix("sk-") && key.count >= 20 && !key.contains(where: \.isWhitespace)
    }

    func validateAPIKey(_ apiKey: String) async throws {
        guard Self.hasPlausibleAPIKeyFormat(apiKey) else { throw TutorAPIError.authentication }
        var request = URLRequest(url: modelsEndpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TutorAPIError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw TutorAPIError.authentication }
        guard (200..<300).contains(http.statusCode) else {
            throw TutorAPIError.service("OpenAI could not validate the key right now (status \(http.statusCode)). Try again.")
        }
    }

    func diagnose(
        apiKey: String,
        question: String,
        screen: CapturedScreen,
        recentFrames: [CapturedScreen] = [],
        recentContext: String,
        learnerMemory: String,
        safetyIdentifier: String,
        onQuestionProgress: (@MainActor (String) -> Void)? = nil
    ) async throws -> TutorResult<DiagnosticPlan> {
        let prompt = """
        Learner question: \(question)
        Context mode: \(screen.target.windowTitle.isEmpty ? "Selected context" : screen.target.windowTitle)

        Recent notebook:
        \(recentContext.isEmpty ? "No current-session notes." : recentContext)

        Persistent learner memory:
        \(learnerMemory)

        The newest image is exactly the scope the learner chose. In Point mode, the warm orange halo is the object they mean. In Freehand Loop mode, everything outside the learner's loop has already been removed locally. If multiple timestamped frames are present, reason about what changed across the sequence; do not treat them as unrelated images.
        Before teaching, identify the visible object and ask ONE short diagnostic question with 2–3 concrete options that distinguish likely misconceptions. Do not explain or solve yet. Use priorConnection only when the stored evidence genuinely supports it; otherwise leave it empty. Use a stable lowercase conceptID such as function-horizontal-translation or attention-scaling.
        """
        return try await structuredRequest(
            apiKey: apiKey,
            model: "gpt-5.6-terra",
            reasoningEffort: "low",
            instructions: Self.diagnosticInstructions,
            prompt: prompt,
            images: recentFrames.isEmpty ? [screen] : recentFrames,
            imageDetail: "low",
            imageMaxDimension: 1_024,
            maxOutputTokens: 450,
            format: Self.diagnosticFormat,
            safetyIdentifier: safetyIdentifier,
            partialTextKey: "question",
            onPartialText: onQuestionProgress
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
        safetyIdentifier: String,
        onNarrationProgress: (@MainActor (String) -> Void)? = nil
    ) async throws -> TutorResult<LessonPlan> {
        let model = precisionMode ? "gpt-5.6-sol" : "gpt-5.6-terra"
        let prompt = """
        Original question: \(originalQuestion)
        Context mode: \(screen.target.windowTitle.isEmpty ? "Selected context" : screen.target.windowTitle)
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
            imageMaxDimension: precisionMode ? nil : 1_024,
            maxOutputTokens: precisionMode ? 1_400 : 1_200,
            format: Self.lessonFormat,
            safetyIdentifier: safetyIdentifier,
            partialTextKey: "narration",
            onPartialText: onNarrationProgress
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
            imageMaxDimension: nil,
            maxOutputTokens: 450,
            format: Self.assessmentFormat,
            safetyIdentifier: safetyIdentifier,
            partialTextKey: nil,
            onPartialText: nil
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
        imageMaxDimension: Int?,
        maxOutputTokens: Int,
        format: [String: Any],
        safetyIdentifier: String,
        partialTextKey: String?,
        onPartialText: (@MainActor (String) -> Void)?
    ) async throws -> TutorResult<Value> {
        var content: [[String: Any]] = [["type": "input_text", "text": prompt]]
        for (index, image) in images.suffix(4).enumerated() {
            let age = max(0, Date().timeIntervalSince(image.capturedAt))
            content.append(["type": "input_text", "text": "Frame \(index + 1), captured \(String(format: "%.1f", age)) seconds ago\(image.videoContext.map { ", video time \(String(format: "%.1f", $0.currentTime))s, captions: \($0.captions)" } ?? "")."])
            content.append([
                "type": "input_image",
                "image_url": "data:image/jpeg;base64,\(Self.preparedImageData(image.jpegData, maxDimension: imageMaxDimension).base64EncodedString())",
                "detail": index == images.suffix(4).count - 1 ? imageDetail : "low"
            ])
        }

        let requestBody: [String: Any] = [
            "model": model,
            "store": false,
            "stream": true,
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

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw TutorAPIError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw TutorAPIError.authentication }
        guard (200..<300).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            let object = (try? JSONSerialization.jsonObject(with: errorData)) as? [String: Any]
            let error = object?["error"] as? [String: Any]
            throw TutorAPIError.service(error?["message"] as? String ?? "OpenAI returned status \(http.statusCode).")
        }

        var outputText = ""
        var completedResponse: [String: Any]?
        var lastPartial = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard payload != "[DONE]", let data = payload.data(using: .utf8),
                  let event = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            switch event["type"] as? String {
            case "response.output_text.delta":
                outputText += event["delta"] as? String ?? ""
                if let partialTextKey,
                   let partial = Self.partialJSONStringValue(forKey: partialTextKey, in: outputText),
                   partial != lastPartial {
                    lastPartial = partial
                    await onPartialText?(partial)
                }
            case "response.completed":
                completedResponse = event["response"] as? [String: Any]
            case "response.failed":
                let response = event["response"] as? [String: Any]
                let error = response?["error"] as? [String: Any]
                throw TutorAPIError.service(error?["message"] as? String ?? "OpenAI could not complete this teaching turn.")
            case "error":
                throw TutorAPIError.service(event["message"] as? String ?? "OpenAI could not complete this teaching turn.")
            default:
                continue
            }
        }

        if outputText.isEmpty, let completedResponse {
            outputText = Self.outputText(from: completedResponse) ?? ""
        }
        guard let valueData = outputText.data(using: .utf8) else {
            throw TutorAPIError.invalidResponse
        }

        let value = try JSONDecoder().decode(Value.self, from: valueData)
        let usageObject = completedResponse?["usage"] as? [String: Any]
        let inputTokens = usageObject?["input_tokens"] as? Int ?? 0
        let outputTokens = usageObject?["output_tokens"] as? Int ?? 0
        let usage = APIUsage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: usageObject?["total_tokens"] as? Int ?? (inputTokens + outputTokens)
        )
        return TutorResult(value: value, usage: usage)
    }

    /// Keeps ordinary tutor turns economical while retaining original pixels for
    /// the explicit high-precision path used for dense spatial localization.
    static func preparedImageData(_ data: Data, maxDimension: Int?) -> Data {
        guard let maxDimension,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              max(width, height) > maxDimension else { return data }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let resized = NSBitmapImageRep(cgImage: thumbnail).representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.82]
              ) else { return data }
        return resized
    }

    static func imagePixelSize(_ data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        return CGSize(width: width, height: height)
    }

    /// Extracts a string field that may not have closed yet. The completed JSON
    /// is still decoded strictly; this is display-only progress for SSE deltas.
    static func partialJSONStringValue(forKey key: String, in json: String) -> String? {
        guard let keyRange = json.range(of: "\"\(key)\"") else { return nil }
        var cursor = keyRange.upperBound
        while cursor < json.endIndex, json[cursor] != ":" { cursor = json.index(after: cursor) }
        guard cursor < json.endIndex else { return nil }
        cursor = json.index(after: cursor)
        while cursor < json.endIndex, json[cursor].isWhitespace { cursor = json.index(after: cursor) }
        guard cursor < json.endIndex, json[cursor] == "\"" else { return nil }
        cursor = json.index(after: cursor)

        var value = ""
        while cursor < json.endIndex {
            let character = json[cursor]
            if character == "\"" { return value }
            if character != "\\" {
                value.append(character)
                cursor = json.index(after: cursor)
                continue
            }

            let escapedIndex = json.index(after: cursor)
            guard escapedIndex < json.endIndex else { return value }
            let escaped = json[escapedIndex]
            switch escaped {
            case "\"", "\\", "/": value.append(escaped)
            case "b": value.append("\u{8}")
            case "f": value.append("\u{c}")
            case "n": value.append("\n")
            case "r": value.append("\r")
            case "t": value.append("\t")
            case "u":
                var digits = ""
                var digitIndex = json.index(after: escapedIndex)
                for _ in 0..<4 {
                    guard digitIndex < json.endIndex else { return value }
                    digits.append(json[digitIndex])
                    digitIndex = json.index(after: digitIndex)
                }
                if let scalarValue = UInt32(digits, radix: 16), let scalar = UnicodeScalar(scalarValue) {
                    value.unicodeScalars.append(scalar)
                }
                cursor = digitIndex
                continue
            default: value.append(escaped)
            }
            cursor = json.index(after: escapedIndex)
        }
        return value
    }

    private static func outputText(from root: [String: Any]) -> String? {
        guard let output = root["output"] as? [[String: Any]],
              let message = output.first(where: { $0["type"] as? String == "message" }),
              let content = message["content"] as? [[String: Any]] else { return nil }
        return content.first(where: { $0["type"] as? String == "output_text" })?["text"] as? String
    }

    private static let diagnosticInstructions = """
    You are Aster✱’s diagnostic tutor. Look closely at the exact object the learner selected and ask ONE short, specific question that pinpoints where their understanding most likely breaks for THIS content. Ground every option in what is actually visible; never ask a generic "do you understand this?" question. Give 2–3 concrete options that are genuinely different misconceptions a real learner holds about this exact thing, each under about eight words and clearly distinct from the others. Do not teach, explain, solve, or annotate yet. Connect to persistent mastery evidence only when it is explicitly present.
    """

    private static let lessonInstructions = """
    You are Aster✱, a calm spatial STEM tutor. Teach one causal or structural idea at a time in intuitive language. Voice is the teacher; notebook text preserves only the key insight; annotations point to the exact visible evidence. Scaffold rather than solve. End with an independent check. For anatomy, teach only labeled educational diagrams and never diagnose or interpret clinical imagery.
    """

    private static let assessmentInstructions = """
    You are Aster✱’s understanding checker. Judge the learner's reasoning against the stated success criteria. Be generous about phrasing and strict about the central concept. Update memory only from demonstrated evidence. If incorrect, identify one precise shaky area and a different next teaching strategy.
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
        "color": ["type": "string", "enum": ["signal", "mint", "coral", "blue"]]
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
                                        "color": ["type": "string", "enum": ["signal", "mint", "coral", "blue"]]
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
