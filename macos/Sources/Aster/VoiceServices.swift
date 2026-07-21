import AVFoundation
import Foundation
import Speech

@MainActor
final class VoiceServices: NSObject, AVSpeechSynthesizerDelegate {
    private enum CaptureMode {
        case wake
        case question(strippingWakePhrase: Bool)
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var hasInputTap = false
    private var wakeRequested = false
    private var captureMode: CaptureMode?
    private var captureGeneration = UUID()
    private var lastQuestionText = ""
    private var silenceWorkItem: DispatchWorkItem?
    var onText: ((String) -> Void)?
    var onFinalText: ((String) -> Void)?
    var onFinished: (() -> Void)?
    var onWakeWord: (() -> Void)?
    var onWakeStatus: ((WakeListeningState) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, rate: Float = 0.48) {
        if case .wake = captureMode {
            stopAudioCapture()
            onWakeStatus?(.paused)
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = min(max(rate, 0.34), 0.62)
        utterance.pitchMultiplier = 1.02
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func stopSpeaking() { synthesizer.stopSpeaking(at: .immediate) }

    func startListening() {
        if case .wake = captureMode { onWakeStatus?(.paused) }
        requestSpeechAccess { [weak self] authorized in
            guard let self else { return }
            guard authorized else {
                self.onFinalText?("")
                return
            }
            self.beginAudioCapture(mode: .question(strippingWakePhrase: false))
        }
    }

    func requestPermissions(completion: @escaping @MainActor () -> Void) {
        SFSpeechRecognizer.requestAuthorization { _ in
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in completion() }
            }
        }
    }

    func startWakeListening() {
        wakeRequested = true
        onWakeStatus?(.starting)
        requestSpeechAccess { [weak self] authorized in
            guard let self else { return }
            guard self.wakeRequested else {
                self.onWakeStatus?(.off)
                return
            }
            guard authorized else {
                self.onWakeStatus?(.needsPermission)
                return
            }
            guard self.recognizer?.supportsOnDeviceRecognition == true else {
                self.onWakeStatus?(.unavailable("On-device wake recognition is unavailable on this Mac"))
                return
            }
            self.beginAudioCapture(mode: .wake)
        }
    }

    func stopWakeListening() {
        wakeRequested = false
        if case .wake = captureMode { stopAudioCapture() }
        onWakeStatus?(.off)
    }

    private func requestSpeechAccess(_ completion: @escaping @MainActor (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                Task { @MainActor in completion(false) }
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    guard self != nil else { return }
                    completion(granted)
                }
            }
        }
    }

    private func beginAudioCapture(mode: CaptureMode) {
        stopAudioCapture()
        guard recognizer?.isAvailable == true else {
            if case .wake = mode { onWakeStatus?(.unavailable("Speech recognition is temporarily unavailable")) }
            else { onFinalText?("") }
            return
        }
        captureMode = mode
        lastQuestionText = ""
        let generation = UUID()
        captureGeneration = generation
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if recognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasInputTap = true
        audioEngine.prepare()
        do {
            try audioEngine.start()
            if case .wake = mode { onWakeStatus?(.listening) }
        } catch {
            stopAudioCapture()
            if case .wake = mode { onWakeStatus?(.unavailable("Could not start the microphone listener")) }
            else { onFinalText?("") }
            return
        }
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            let rawText = result?.bestTranscription.formattedString ?? ""
            Task { @MainActor in
                guard let self, self.captureGeneration == generation else { return }
                switch self.captureMode {
                case .wake:
                    if Self.containsWakePhrase(rawText) {
                        self.captureMode = .question(strippingWakePhrase: true)
                        self.onWakeStatus?(.paused)
                        self.onWakeWord?()
                        let question = Self.questionAfterWakePhrase(rawText)
                        if !question.isEmpty { self.publishQuestionText(question) }
                        return
                    }
                    if error != nil || result?.isFinal == true {
                        self.stopAudioCapture()
                        self.restartWakeCapture(after: 0.35)
                    }
                case .question(let strippingWakePhrase):
                    let text = strippingWakePhrase ? Self.questionAfterWakePhrase(rawText) : rawText
                    if !text.isEmpty { self.publishQuestionText(text) }
                    if error != nil || result?.isFinal == true {
                        if text.isEmpty, strippingWakePhrase {
                            self.stopAudioCapture()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                                self?.beginAudioCapture(mode: .question(strippingWakePhrase: false))
                            }
                        } else {
                            self.finalizeQuestion(text)
                        }
                    }
                case nil:
                    break
                }
            }
        }
    }

    func stopListening(resumeWake: Bool = true) {
        stopAudioCapture()
        if resumeWake { restartWakeCapture(after: 0.5) }
    }

    private func stopAudioCapture() {
        silenceWorkItem?.cancel()
        silenceWorkItem = nil
        captureGeneration = UUID()
        if audioEngine.isRunning { audioEngine.stop() }
        if hasInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        captureMode = nil
    }

    private func publishQuestionText(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        lastQuestionText = cleaned
        onText?(cleaned)
        silenceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.finalizeQuestion(self?.lastQuestionText ?? "") }
        }
        silenceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15, execute: work)
    }

    private func finalizeQuestion(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        stopAudioCapture()
        onFinalText?(cleaned)
    }

    private func restartWakeCapture(after delay: TimeInterval) {
        guard wakeRequested else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.wakeRequested, !self.audioEngine.isRunning else { return }
            self.startWakeListening()
        }
    }

    static func containsWakePhrase(_ text: String) -> Bool {
        let normalized = text.lowercased()
            .replacingOccurrences(of: "[^a-z ]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
        return normalized.contains("hey aster") || normalized.contains("hey astor") || normalized.contains("hey esther")
    }

    static func questionAfterWakePhrase(_ text: String) -> String {
        text.replacingOccurrences(
            of: "(?i)^.*?\\bhey\\s+(aster|astor|esther)\\b[\\s,;:.!?—-]*",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in onFinished?() }
    }
}
