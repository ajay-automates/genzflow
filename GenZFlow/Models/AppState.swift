import Foundation
import SwiftUI

enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case translating
    case done(String)
    case error(String)
    
    var statusText: String {
        switch self {
        case .idle: return "Ready \u{2014} press Control + Option + Space to talk"
        case .recording: return "Listening..."
        case .transcribing: return "Transcribing..."
        case .translating: return "Making it gen z..."
        case .done(let text): return "Done: \(text.prefix(50))..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    var isProcessing: Bool {
        switch self {
        case .recording, .transcribing, .translating: return true
        default: return false
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var isWhisperReady: Bool = false
    @Published var lastTranslation: String = ""
    @Published var originalTranscript: String = ""
    @Published var translationCount: Int = 0
    @Published var selectedStyle: SlangStyle = Config.defaultStyle
    
    func reset() {
        recordingState = .idle
        originalTranscript = ""
    }
}
