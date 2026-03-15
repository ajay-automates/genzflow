import Foundation

enum AppConfig {
    static let openAIAPIKey: String = {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }()

    static let openAIModel = "gpt-4o"
    static let whisperModel = "base"
    static let audioSampleRate: Double = 16000.0
    static let maxRecordingDuration: TimeInterval = 30.0
    static let defaultStyle: SlangStyle = .genZ
}

enum SlangStyle: String, CaseIterable, Identifiable {
    case genZ = "Gen Z"
    case brainrot = "Brainrot"
    case corporate = "Corporate Gen Z"
    case shakespeare = "Shakespeare"
    case pirate = "Pirate"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .genZ: return "flame.fill"
        case .brainrot: return "brain.head.profile"
        case .corporate: return "briefcase.fill"
        case .shakespeare: return "text.book.closed.fill"
        case .pirate: return "flag.fill"
        }
    }

    var systemPrompt: String {
        switch self {
        case .genZ:
            return """
            You are a Gen Z slang translator. Rewrite the given text in authentic Gen Z slang.
            Rules: Keep core meaning. Use slang naturally (no cap, fr fr, lowkey, slay, bussin, its giving, ate, rizz, sigma, aura). Don't force it. Match energy of original. Keep concise. Output ONLY translated text.
            """
        case .brainrot:
            return """
            You are a maximum brainrot translator. Rewrite in unhinged TikTok brainrot slang.
            Rules: Go full brainrot (skibidi, sigma, rizz, gyatt, mewing, fanum tax, ohio, edge, aura points). Capitalize randomly. Keep readable but UNHINGED. Output ONLY translated text.
            """
        case .corporate:
            return """
            You are a Corporate Gen Z translator. Professional but with Gen Z energy.
            Rules: Workplace appropriate with Gen Z flavor (slay, ate, no notes, understood the assignment, main character, era, vibe). Output ONLY translated text.
            """
        case .shakespeare:
            return """
            You are a Shakespearean translator. Rewrite in William Shakespeare's style.
            Rules: Use thee, thou, thy, hath, doth, wherefore, forsooth, prithee, alas, hark. Early modern English grammar. Dramatic but concise. Output ONLY translated text.
            """
        case .pirate:
            return """
            You are a pirate translator. Rewrite as a swashbuckling pirate.
            Rules: Use arr, matey, ye, yer, avast, shiver me timbers, blimey, walk the plank. Replace words with pirate equivalents. Fun and readable. Output ONLY translated text.
            """
        }
    }
}
