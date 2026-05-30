import Foundation
import Speech
import AVFoundation

@MainActor
@Observable
final class SpeechRecognitionService: NSObject {
    var transcript: String = ""
    var isListening: Bool = false
    var error: String? = nil
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    // nonisolated(unsafe): these are only mutated from startListening/stopListening
    // (both run on the main actor) but the audio tap callback captures them by
    // local value, so no cross-actor access occurs at runtime.
    nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    nonisolated(unsafe) private var recognitionTask: SFSpeechRecognitionTask?
    nonisolated(unsafe) private let audioEngine = AVAudioEngine()
    nonisolated(unsafe) private var isTapInstalled = false

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
        guard !isListening else { return }

        // Speech permission
        if authorizationStatus != .authorized {
            let granted = await requestAuthorization()
            guard granted else {
                error = "Speech recognition permission denied. Enable in Settings → Privacy → Speech Recognition."
                return
            }
        }

        // Microphone permission
        let micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
        }
        guard micGranted else {
            error = "Microphone permission denied. Enable in Settings → Privacy → Microphone."
            return
        }

        // Tear down any leftover state
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        if audioEngine.isRunning { audioEngine.stop() }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // IMPORTANT: capture `request` by local value — do NOT reference `self` or
        // any @MainActor-isolated property inside this closure. The audio tap runs
        // on a private audio thread; touching actor-isolated state from there
        // triggers a Swift 6 runtime isolation trap.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        isTapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        transcript = ""

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, err in
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor [weak self] in self?.transcript = text }
            }
            if err != nil || result?.isFinal == true {
                Task { @MainActor [weak self] in self?.stopListening() }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        audioEngine.stop()
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func parseTransactionFromSpeech(_ text: String) -> ParsedTransaction? {
        let lowercased = text.lowercased()
        let amountPattern = #"(\$|€|£)?\s?(\d+(?:\.\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: amountPattern),
              let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
              let amountRange = Range(match.range(at: 2), in: lowercased),
              let amount = Double(lowercased[amountRange]) else { return nil }

        let incomeKeywords = ["received", "earned", "got paid", "income", "salary", "freelance", "refund"]
        let isIncome = incomeKeywords.contains { lowercased.contains($0) }

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
    var suggestedCategoryName: String? = nil
}
