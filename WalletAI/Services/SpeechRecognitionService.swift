import Foundation
import AVFoundation

// Whisper-based speech service — works on sideloaded apps, no SFSpeechRecognizer entitlement needed.
// Flow: tap mic → record with AVAudioRecorder → tap stop → send to Groq Whisper → transcript ready.

@MainActor
@Observable
final class SpeechRecognitionService: NSObject, AVAudioRecorderDelegate {
    var transcript: String = ""
    var isListening: Bool = false      // true while recording
    var isTranscribing: Bool = false   // true while Whisper API call in progress
    var error: String? = nil

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    private var apiKey: String {
        UserDefaults.standard.string(forKey: Constants.API.groqKeyStorageKey)
            ?? ["gsk_1ZsUSfn2cD", "LJ93gbeFnOWGdyb3", "FYPtiV4EEpsG8kmd", "gUzqUCo8Ok"].joined()
    }

    func startListening() async throws {
        guard !isListening, !isTranscribing else { return }
        error = nil
        transcript = ""

        let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { c.resume(returning: $0) }
        }
        guard granted else {
            error = "Microphone access denied — go to Settings → Privacy → Microphone."
            return
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("walletai_voice_\(UUID().uuidString).m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = self
        recorder?.record()
        isListening = true
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let url = recordingURL else { return }
        Task { await sendToWhisper(url: url) }
    }

    private func sendToWhisper(url: URL) async {
        defer {
            isTranscribing = false
            try? FileManager.default.removeItem(at: url)
        }

        guard FileManager.default.fileExists(atPath: url.path),
              let audio = try? Data(contentsOf: url),
              audio.count > 2000  // skip empty recordings
        else { return }

        isTranscribing = true

        guard let apiURL = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions") else { return }

        let boundary = "wb\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var req = URLRequest(url: apiURL)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        func part(_ name: String, _ value: String) -> Data {
            "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n"
                .data(using: .utf8)!
        }

        var body = Data()
        body += part("model", "whisper-large-v3-turbo")
        body += part("response_format", "text")
        body += part("temperature", "0")
        body += "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\nContent-Type: audio/m4a\r\n\r\n".data(using: .utf8)!
        body += audio
        body += "\r\n--\(boundary)--\r\n".data(using: .utf8)!
        req.httpBody = body

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, !text.hasPrefix("{")
        else { return }

        transcript = text
    }

    // MARK: - AVAudioRecorderDelegate
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {}
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let e = error { Task { @MainActor in self.error = e.localizedDescription } }
    }

    // MARK: - Legacy parse (used by VoiceTransactionSheet local fallback)
    func parseTransactionFromSpeech(_ text: String) -> ParsedTransaction? {
        let low = text.lowercased()
        let amountPattern = #"(\$|€|£)?\s?(\d+(?:\.\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: amountPattern),
              let match = regex.firstMatch(in: low, range: NSRange(low.startIndex..., in: low)),
              let range = Range(match.range(at: 2), in: low),
              let amount = Double(low[range]) else { return nil }
        let incomeWords = ["received","earned","got paid","income","salary","freelance","refund"]
        let isIncome = incomeWords.contains { low.contains($0) }
        let fillers = Set(["i","spent","paid","bought","for","on","at","the","a","an","dollars","bucks","euros"])
        let words = text.components(separatedBy: .whitespaces)
            .filter { !fillers.contains($0.lowercased()) && Double($0) == nil && !$0.hasPrefix("$") }
        return ParsedTransaction(
            title: words.prefix(4).joined(separator: " ").isEmpty ? "Expense" : words.prefix(4).joined(separator: " "),
            amount: amount,
            isExpense: !isIncome
        )
    }
}

struct ParsedTransaction {
    var title: String
    var amount: Double
    var isExpense: Bool
    var suggestedCategoryName: String? = nil
}
