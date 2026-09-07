//
//  OpenRouterAccountClient.swift
//  Y1Y
//

import Foundation

protocol OpenRouterAccountServing {
    func fetchAvailableBalance(
        baseURL: String,
        apiKey: String
    ) async throws -> Decimal

    func checkConnection(
        baseURL: String,
        apiKey: String
    ) async throws
}

struct OpenRouterAccountClient: OpenRouterAccountServing {
    private let session: URLSession
    private let timeout: TimeInterval

    init(
        session: URLSession = .shared,
        timeout: TimeInterval = 10
    ) {
        self.session = session
        self.timeout = timeout
    }

    func fetchAvailableBalance(
        baseURL: String,
        apiKey: String
    ) async throws -> Decimal {
        let request = try makeRequest(
            baseURL: baseURL,
            path: "credits",
            apiKey: apiKey
        )
        let response: CreditsResponse = try await send(
            request,
            apiKey: apiKey
        )
        return response.data.totalCredits - response.data.totalUsage
    }

    func checkConnection(
        baseURL: String,
        apiKey: String
    ) async throws {
        let request = try makeRequest(
            baseURL: baseURL,
            path: "key",
            apiKey: apiKey
        )
        let _: CurrentKeyResponse = try await send(
            request,
            apiKey: apiKey
        )
    }

    private func makeRequest(
        baseURL: String,
        path: String,
        apiKey: String
    ) throws -> URLRequest {
        guard let url = URL(
            string: "\(normalizedBaseURL(baseURL))/\(path)"
        ) else {
            throw OpenRouterAccountClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue(
            "Bearer \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<Response: Decodable>(
        _ request: URLRequest,
        apiKey: String
    ) async throws -> Response {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenRouterAccountClientError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = sanitizedServerMessage(
                    from: data,
                    apiKey: apiKey
                )
                throw OpenRouterAccountClientError.httpStatus(
                    code: httpResponse.statusCode,
                    message: message
                )
            }

            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                throw OpenRouterAccountClientError.invalidPayload
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where error.code == .timedOut {
            throw OpenRouterAccountClientError.timedOut
        } catch let error as OpenRouterAccountClientError {
            throw error
        } catch {
            throw OpenRouterAccountClientError.transport(
                message: sanitized(
                    error.localizedDescription,
                    removing: apiKey
                )
            )
        }
    }

    private func normalizedBaseURL(_ baseURL: String) -> String {
        var value = baseURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        while value.hasSuffix("/") {
            value.removeLast()
        }
        if !value.hasSuffix("/v1") {
            value += "/v1"
        }
        return value
    }

    private func sanitizedServerMessage(
        from data: Data,
        apiKey: String
    ) -> String {
        if let response = try? JSONDecoder().decode(
            ErrorResponse.self,
            from: data
        ) {
            return sanitized(response.error.message, removing: apiKey)
        }
        return "Request failed"
    }

    private func sanitized(_ message: String, removing apiKey: String) -> String {
        guard !apiKey.isEmpty else { return message }
        return message.replacingOccurrences(of: apiKey, with: "[REDACTED]")
    }
}

enum OpenRouterAccountClientError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case invalidPayload
    case timedOut
    case httpStatus(code: Int, message: String)
    case transport(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "OpenRouter API 地址无效。"
        case .invalidResponse:
            return "OpenRouter 返回了无效响应。"
        case .invalidPayload:
            return "OpenRouter 返回的数据格式无效。"
        case .timedOut:
            return "连接 OpenRouter 超时。"
        case .httpStatus(let code, let message):
            return "OpenRouter 请求失败（HTTP \(code)）：\(message)"
        case .transport(let message):
            return "无法连接 OpenRouter：\(message)"
        }
    }
}

private struct CreditsResponse: Decodable {
    let data: CreditsData
}

private struct CreditsData: Decodable {
    let totalCredits: Decimal
    let totalUsage: Decimal

    enum CodingKeys: String, CodingKey {
        case totalCredits = "total_credits"
        case totalUsage = "total_usage"
    }
}

private struct CurrentKeyResponse: Decodable {
    let data: CurrentKeyData
}

private struct CurrentKeyData: Decodable {
    let label: String?
}

private struct ErrorResponse: Decodable {
    let error: ErrorData
}

private struct ErrorData: Decodable {
    let message: String
}
