import AVFoundation
import Foundation
import Speech

@MainActor
final class VoiceServices: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var hasInputTap = false
    private var wakeRequested = false
    private var isWakeCapture = false
    private var captureGeneration = UUID()
    var onText: ((String) -> Void)?
    var onFinalText: ((String) -> Void)?
    var onFinished: (() -> Void)?
    var onWakeWord: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, rate: Float = 0.48) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = min(max(rate, 0.34), 0.62)
        utterance.pitchMultiplier = 1.02
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func stopSpeaking() { synthesizer.stopSpeaking(at: .immediate) }

    func startListening() {
        isWakeCapture = false
        requestSpeechAccess { [weak self] in self?.beginAudioCapture(wakeOnly: false) }
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
        requestSpeechAccess { [weak self] in self?.beginAudioCapture(wakeOnly: true) }
    }

    func stopWakeListening() {
        wakeRequested = false
        if isWakeCapture { stopAudioCapture() }
    }

    private func requestSpeechAccess(_ authorized: @escaping @MainActor () -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                guard granted else { return }
                Task { @MainActor in
                    guard self != nil else { return }
                    authorized()
                }
            }
        }
    }

    private func beginAudioCapture(wakeOnly: Bool) {
        stopAudioCapture()
        isWakeCapture = wakeOnly
        let generation = UUID()
        captureGeneration = generation
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasInputTap = true
        audioEngine.prepare()
        do { try audioEngine.start() } catch { return }
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString ?? ""
            Task { @MainActor in
                guard let self, self.captureGeneration == generation else { return }
                if wakeOnly {
                    if Self.containsWakePhrase(text) {
                        self.stopAudioCapture()
                        self.onWakeWord?()
                        self.restartWakeCapture(after: 1.0)
                        return
                    }
                } else if !text.isEmpty {
                    self.onText?(text)
                }
                if error != nil || result?.isFinal == true {
                    self.stopAudioCapture()
                    if wakeOnly {
                        self.restartWakeCapture(after: 0.35)
                    } else {
                        if !text.isEmpty { self.onFinalText?(text) }
                        self.restartWakeCapture(after: 0.8)
                    }
                }
            }
        }
    }

    func stopListening() {
        stopAudioCapture()
        restartWakeCapture(after: 0.5)
    }

    private func stopAudioCapture() {
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
        isWakeCapture = false
    }

    private func restartWakeCapture(after delay: TimeInterval) {
        guard wakeRequested else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.wakeRequested, !self.audioEngine.isRunning else { return }
            self.beginAudioCapture(wakeOnly: true)
        }
    }

    static func containsWakePhrase(_ text: String) -> Bool {
        let normalized = text.lowercased()
            .replacingOccurrences(of: "[^a-z ]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
        return normalized.contains("hey aster") || normalized.contains("hey astor")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in onFinished?() }
    }
}
