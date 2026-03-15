import Foundation
import WhisperKit

class TranscriptionService {
    private var whisperKit: WhisperKit?
    private(set) var isReady = false
    
    func setup() async throws {
        print("[TranscriptionService] Loading WhisperKit model: \(Config.whisperModel)...")
        let whisper = try await WhisperKit(model: Config.whisperModel, verbose: false, logLevel: .error)
        self.whisperKit = whisper; self.isReady = true
        print("[TranscriptionService] WhisperKit ready")
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        guard let whisper = whisperKit, isReady else { throw TranscriptionError.notReady }
        let results = try await whisper.transcribe(
            audioPath: audioURL.path(),
            decodeOptions: DecodingOptions(language: "en", temperatureFallbackCount: 3, sampleLength: 224, usePrefillPrompt: true, skipSpecialTokens: true, withoutTimestamps: true)
        )
        guard let transcription = results.first else { throw TranscriptionError.emptyResult }
        let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.emptyResult }
        print("[TranscriptionService] Transcribed: \"\(text.prefix(80))...\"")
        return text
    }
}

enum TranscriptionError: LocalizedError {
    case notReady, emptyResult
    var errorDescription: String? {
        switch self {
        case .notReady: return "WhisperKit not initialized yet"
        case .emptyResult: return "No speech detected"
        }
    }
}
