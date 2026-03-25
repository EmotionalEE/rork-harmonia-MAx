import Foundation

nonisolated struct ChatAPIMessage: Codable, Sendable {
    let role: String
    let content: String
}

nonisolated struct ChatAPIRequest: Codable, Sendable {
    let messages: [ChatAPIMessage]
    let system: String?
}

nonisolated struct ChatAPIChoice: Codable, Sendable {
    let message: ChatAPIMessage
}

nonisolated struct ChatAPIResponse: Codable, Sendable {
    let text: String?
    let choices: [ChatAPIChoice]?
}

@MainActor
@Observable
final class ChatService {
    private let baseURL: String = Config.EXPO_PUBLIC_TOOLKIT_URL

    func sendMessage(history: [ChatMessage], systemPrompt: String) async -> String? {
        guard !baseURL.isEmpty else {
            return localFallback(for: history.last?.text ?? "")
        }

        let endpoint = baseURL.hasSuffix("/") ? "\(baseURL)agent/chat" : "\(baseURL)/agent/chat"
        guard let url = URL(string: endpoint) else {
            return localFallback(for: history.last?.text ?? "")
        }

        let apiMessages = history.map { ChatAPIMessage(role: $0.role, content: $0.text) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "messages": apiMessages.map { ["role": $0.role, "content": $0.content] },
            "system": systemPrompt
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return localFallback(for: history.last?.text ?? "")
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let text = json["text"] as? String, !text.isEmpty {
                    return text
                }
                if let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let message = first["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return content
                }
            }

            if let rawText = String(data: data, encoding: .utf8), !rawText.isEmpty {
                return rawText
            }

            return localFallback(for: history.last?.text ?? "")
        } catch {
            return localFallback(for: history.last?.text ?? "")
        }
    }

    private func localFallback(for input: String) -> String {
        let lenses: [String] = [
            "When you say '\(input)', I hear a part of you asking for more room. Where do you feel the tightest edge of it?",
            "That phrase carries weight. What would become simpler if you didn't have to hold all of it alone?",
            "There's useful information in what you're sharing. If your body could ask for one small kindness next, what would it ask for?",
            "I notice the rhythm in what you're saying. Does it feel more like pressure, ache, or restlessness right now?",
            "Stay with that for a moment. What feels truest underneath it?",
            "Thank you for naming that. What would it look like to give yourself permission to feel it fully, just for a breath?"
        ]
        return lenses.randomElement() ?? "Stay with that. What feels truest underneath it?"
    }
}
