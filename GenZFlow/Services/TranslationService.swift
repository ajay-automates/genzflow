import Foundation

class TranslationService {
    private let apiKey: String
    private let model: String
    private let session: URLSession
    var currentStyle: SlangStyle = AppConfig.defaultStyle
    
    init(apiKey: String = AppConfig.openAIAPIKey, model: String = AppConfig.openAIModel) {
        self.apiKey = apiKey; self.model = model
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    func translate(_ text: String) async throws -> String {
        guard !apiKey.isEmpty else { throw TranslationError.missingAPIKey }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": currentStyle.systemPrompt],
                ["role": "user", "content": text]
            ],
            "max_tokens": 500, "temperature": 0.8
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw TranslationError.invalidResponse }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TranslationError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else { throw TranslationError.parseError }
        let translated = content.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[TranslationService] [\(currentStyle.rawValue)] \"\(translated.prefix(80))...\"")
        return translated
    }
}

enum TranslationError: LocalizedError {
    case missingAPIKey, invalidResponse, apiError(statusCode: Int, message: String), parseError
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing OpenAI API key. Set OPENAI_API_KEY before launching GenZFlow."
        case .invalidResponse: return "Invalid API response"
        case .apiError(let code, let msg): return "API error (\(code)): \(msg.prefix(100))"
        case .parseError: return "Failed to parse API response"
        }
    }
}
