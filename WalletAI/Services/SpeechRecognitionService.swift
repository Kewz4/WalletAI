import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
@Observable
final class SpeechRecognitionService: NSObject {
    var transcript: String = ""
    var isListening: Bool = false
    var error: String? = nil
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        super.init()
        checkAuthorization()
    }

    func checkAuthorization() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        authorizationStatus = status
        return status == .authorized
    }

    func startListening() async throws {
        if authorizationStatus != .authorized {
            let granted = await requestAuthorization()
            guard granted else {
                error = "Speech recognition permission denied."
                return
            }
        }

        if audioEngine.isRunning {
            stopListening()
            return
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        transcript = ""

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, err in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            if err != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopListening()
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func parseTransactionFromSpeech(_ text: String) -> ParsedTransaction? {
        let lowercased = text.lowercased()

        // Extract amount
        let amountPattern = #"(\$|€|£)?\s?(\d+(?:\.\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: amountPattern),
              let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
              let amountRange = Range(match.range(at: 2), in: lowercased),
              let amount = Double(lowercased[amountRange]) else { return nil }

        // Detect expense vs income keywords
        let incomeKeywords = ["received", "earned", "got paid", "income", "salary", "freelance", "refund"]
        let isIncome = incomeKeywords.contains { lowercased.contains($0) }

        // Extract merchant/title (words before/after amount not matching filler words)
        let fillerWords = Set(["i", "spent", "paid", "bought", "for", "on", "at", "the", "a", "an", "dollars", "bucks", "euros"])
        let words = text.components(separatedBy: .whitespaces)
            .filter { !fillerWords.contains($0.lowercased()) }
            .filter { Double($0) == nil && !$0.hasPrefix("$") }
        let title = words.prefix(4).joined(separator: " ")

        return ParsedTransaction(title: title.isEmpty ? "Expense" : title, amount: amount, isExpense: !isIncome)
    }
}

struct ParsedTransaction {
    var title: String
    var amount: Double
    var isExpense: Bool
}
