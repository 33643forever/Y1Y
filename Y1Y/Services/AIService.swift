//
//  AIService.swift
//  Y1Y
//

import Foundation
import Combine

class AIService: ObservableObject {
    @Published var responseText: String = ""
    @Published var reasoningText: String = ""
    @Published var isLoading: Bool = false
    @Published var isReasoning: Bool = false
    @Published var errorMessage: String?

    private var currentTask: Task<Void, Never>?

    /// The URL session used for network requests.
    /// Can be overridden for testing with mock responses.
    var urlSession: URLSession

    init(urlSession: URLSession = AIService.directSession) {
        self.urlSession = urlSession
    }

    /// Normalizes the base URL to ensure it ends with /v1
    static func normalizedBaseURL(_ baseURL: String) -> String {
        var url = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !url.hasSuffix("/v1") {
            url += "/v1"
        }
        return url
    }

    func sendRequest(systemPrompt: String, userContent: String) {
        let settings = SettingsManager.shared
        guard !settings.apiKey.isEmpty else {
            errorMessage = "请先在设置中填写 API Key。"
            return
        }

        cancel()
        responseText = ""
        reasoningText = ""
        errorMessage = nil
        isLoading = true
        isReasoning = false

        currentTask = Task { [weak self] in
            do {
                try await self?.streamChat(
                    baseURL: settings.apiBaseURL,
                    apiKey: settings.apiKey,
                    model: settings.modelName,
                    systemPrompt: systemPrompt,
                    userContent: userContent,
                    enableReasoning: settings.enableReasoning
                )
            } catch is CancellationError {
                // cancelled
            } catch {
                let weakSelf = self
                await MainActor.run {
                    weakSelf?.errorMessage = error.localizedDescription
                    weakSelf?.isLoading = false
                    weakSelf?.isReasoning = false
                }
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        isReasoning = false
    }

    /// A URLSession that bypasses system proxy to avoid auth header stripping.
    /// Some proxies strip the Authorization header, which breaks API authentication.
    /// By bypassing the proxy, the auth header goes directly to the API server.
    private static let directSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [:]
        return URLSession(configuration: config)
    }()

    private func streamChat(
        baseURL: String,
        apiKey: String,
        model: String,
        systemPrompt: String,
        userContent: String,
        enableReasoning: Bool
    ) async throws {
        let url = URL(string: "\(Self.normalizedBaseURL(baseURL))/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        print("[Y1Y] Chat request: reasoning=\(enableReasoning), model=\(model)")

        var messages: [[String: String]] = []
        if !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": userContent])

        var body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": messages
        ]

        if enableReasoning {
            body["include_reasoning"] = true
            body["reasoning"] = ["effort": "medium"]
        }
        // When reasoning is off, omit all reasoning-related parameters.
        // Setting them to false can be misinterpreted by some models/providers.

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (bytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw AIError.httpError(httpResponse.statusCode, errorBody)
        }

        // Track if we've seen any reasoning tokens
        var hasReceivedReasoning = false

        for try await line in bytes.lines {
            try Task.checkCancellation()

            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            if jsonString == "[DONE]" { break }

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any]
            else { continue }

            // Handle reasoning tokens (from delta.reasoning field)
            if let reasoning = delta["reasoning"] as? String, !reasoning.isEmpty {
                if !hasReceivedReasoning {
                    hasReceivedReasoning = true
                    await MainActor.run { [weak self] in
                        self?.isReasoning = true
                    }
                }
                await MainActor.run { [weak self] in
                    self?.reasoningText += reasoning
                }
            }

            // Handle content tokens
            if let content = delta["content"] as? String, !content.isEmpty {
                // If we were reasoning and now getting content, reasoning is done
                if hasReceivedReasoning {
                    await MainActor.run { [weak self] in
                        self?.isReasoning = false
                    }
                }
                await MainActor.run { [weak self] in
                    self?.responseText += content
                }
            }
        }

        await MainActor.run { [weak self] in
            self?.isReasoning = false
            self?.isLoading = false
        }
    }

    // Fetch available models from API
    static func fetchModels(baseURL: String, apiKey: String) async throws -> [String] {
        let url = URL(string: "\(normalizedBaseURL(baseURL))/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await directSession.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.httpError(httpResponse.statusCode, message)
            }
            throw AIError.httpError(httpResponse.statusCode, "Request failed")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]]
        else { return [] }

        return models.compactMap { $0["id"] as? String }.sorted()
    }

}

enum AIError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        }
    }
}
